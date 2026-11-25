# Kiểm thử Auth/Profile trên stack local; không in token hoặc secret key.
$ErrorActionPreference = 'Stop'
$authTestDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Push-Location -LiteralPath $authTestDirectory
try {
    # Windows PowerShell 5.1 coi stderr thông tin của CLI là NativeCommandError.
    $savedErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $authStatusOutput = & npx.cmd supabase status -o json 2>$null
    $authStatusExit = $LASTEXITCODE
    $ErrorActionPreference = $savedErrorPreference
    if ($authStatusExit -ne 0) { throw 'Supabase local chưa chạy. Hãy chạy npx supabase start.' }
    $authStatus = ($authStatusOutput -join "`n") | ConvertFrom-Json
    if (-not $authStatus.PUBLISHABLE_KEY -or $authStatus.API_URL -ne 'http://127.0.0.1:54321') {
        throw 'Chỉ được chạy test với stack local tại 127.0.0.1:54321.'
    }
    & flutter test --no-pub test/integration/auth_local_test.dart --dart-define=RUN_LOCAL_AUTH=true "--dart-define=LOCAL_SUPABASE_PUBLISHABLE_KEY=$($authStatus.PUBLISHABLE_KEY)" --reporter expanded
    if ($LASTEXITCODE -ne 0) { throw 'Kiểm thử Auth/Profile local chưa đạt.' }
} finally {
    Pop-Location
}
