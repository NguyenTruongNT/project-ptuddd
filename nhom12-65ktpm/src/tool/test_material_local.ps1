# Local only. Secret stays in the test process environment, never a Flutter define.
$ErrorActionPreference = 'Stop'
$materialTestDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Push-Location -LiteralPath $materialTestDirectory
$previousMaterialAdminKey = $env:MATERIAL_TEST_ADMIN_KEY
try {
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $statusOutput = & npx.cmd supabase@3.3.0 status -o json 2>$null
    $statusExit = $LASTEXITCODE
    $ErrorActionPreference = $savedPreference
    if ($statusExit -ne 0) { throw 'Supabase local chua chay.' }
    $status = ($statusOutput -join "`n") | ConvertFrom-Json
    if ($status.API_URL -ne 'http://127.0.0.1:54321') { throw 'Chi chay voi local.' }
    $env:MATERIAL_TEST_ADMIN_KEY = $status.SERVICE_ROLE_KEY
    if (-not $env:MATERIAL_TEST_ADMIN_KEY) { $env:MATERIAL_TEST_ADMIN_KEY = $status.SECRET_KEY }
    & flutter test test/integration/material_supabase_test.dart --no-pub --reporter expanded --dart-define=RUN_MATERIAL_SUPABASE=true "--dart-define=MATERIAL_TEST_URL=$($status.API_URL)" "--dart-define=MATERIAL_TEST_PUBLIC_KEY=$($status.PUBLISHABLE_KEY)"
    if ($LASTEXITCODE -ne 0) { throw 'Kiem thu Material local chua dat.' }
} finally {
    $env:MATERIAL_TEST_ADMIN_KEY = $previousMaterialAdminKey
    Pop-Location
}
