# Integration against the explicitly approved development project only.
# Keys stay in process memory; admin key is never a Flutter dart-define.
$ErrorActionPreference = 'Stop'
$materialCloudDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$previousMaterialAdminKey = $env:MATERIAL_TEST_ADMIN_KEY
Push-Location -LiteralPath $materialCloudDirectory
try {
    $projectRef = 'dacrjfgleursgtnzeoix'
    $config = Get-Content -Encoding UTF8 -LiteralPath 'assets/config/supabase.public.json' -Raw | ConvertFrom-Json
    if ($config.SUPABASE_URL -ne "https://$projectRef.supabase.co") {
        throw 'Cloud target is not the approved development project.'
    }
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $keyOutput = & npx.cmd supabase@3.3.0 projects api-keys "--remote=$projectRef" --reveal --output-format json 2>$null
    $keyExit = $LASTEXITCODE
    $ErrorActionPreference = $savedPreference
    if ($keyExit -ne 0) { throw 'Cannot access development test credentials.' }
    $keyResult = ($keyOutput -join "`n") | ConvertFrom-Json
    $backendKey = $keyResult.keys | Where-Object { $_.name -eq 'service_role' } | Select-Object -First 1
    if (-not $backendKey.api_key) { throw 'Missing backend test credential.' }
    $env:MATERIAL_TEST_ADMIN_KEY = $backendKey.api_key
    & flutter test test/integration/material_supabase_test.dart --no-pub --reporter expanded --dart-define=RUN_MATERIAL_SUPABASE=true "--dart-define=MATERIAL_TEST_URL=$($config.SUPABASE_URL)" "--dart-define=MATERIAL_TEST_PUBLIC_KEY=$($config.SUPABASE_PUBLISHABLE_KEY)"
    if ($LASTEXITCODE -ne 0) { throw 'Material Cloud integration failed.' }
} finally {
    $env:MATERIAL_TEST_ADMIN_KEY = $previousMaterialAdminKey
    Pop-Location
}
