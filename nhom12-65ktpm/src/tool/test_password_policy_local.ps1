# Local-only password policy test. Never print credentials or tokens.
$ErrorActionPreference = 'Stop'
$policyTestDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Push-Location -LiteralPath $policyTestDirectory
try {
    $savedErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $policyStatusOutput = & npx.cmd supabase status -o json 2>$null
    $policyStatusExit = $LASTEXITCODE
    $ErrorActionPreference = $savedErrorPreference
    if ($policyStatusExit -ne 0) { throw 'Start Supabase local before running this test.' }
    $policyStatus = ($policyStatusOutput -join "`n") | ConvertFrom-Json
    if (-not $policyStatus.PUBLISHABLE_KEY -or $policyStatus.API_URL -ne 'http://127.0.0.1:54321') {
        throw 'Only the local stack at 127.0.0.1:54321 is allowed.'
    }
    & flutter test --no-pub test/integration/password_policy_local_test.dart --dart-define=RUN_LOCAL_PASSWORD_POLICY=true "--dart-define=LOCAL_SUPABASE_PUBLISHABLE_KEY=$($policyStatus.PUBLISHABLE_KEY)" --reporter expanded
    if ($LASTEXITCODE -ne 0) { throw 'Local password policy test failed.' }
} finally {
    Pop-Location
}
