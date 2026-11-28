# Chỉ kiểm thử Supabase local. Không triển khai migration hoặc truyền admin key
# vào Flutter defines; mọi fixture được dọn theo ID trong teardown của test.
$ErrorActionPreference = 'Stop'
$qrTestDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$previousQrAdminKey = $env:QR_TEST_ADMIN_KEY
Push-Location -LiteralPath $qrTestDirectory
try {
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $qrStatusOutput = & npx.cmd supabase@3.3.0 status -o json 2>$null
    $qrStatusExit = $LASTEXITCODE
    $ErrorActionPreference = $savedPreference
    if ($qrStatusExit -ne 0) { throw 'Supabase local chua chay.' }
    $qrStatus = ($qrStatusOutput -join "`n") | ConvertFrom-Json
    if ($qrStatus.API_URL -ne 'http://127.0.0.1:54321') { throw 'Chi cho phep local.' }
    $env:QR_TEST_ADMIN_KEY = $qrStatus.SERVICE_ROLE_KEY
    if (-not $env:QR_TEST_ADMIN_KEY) { $env:QR_TEST_ADMIN_KEY = $qrStatus.SECRET_KEY }
    & flutter test test/integration/qr_home_supabase_test.dart --no-pub --reporter expanded --dart-define=RUN_QR_HOME_LOCAL=true "--dart-define=QR_TEST_URL=$($qrStatus.API_URL)" "--dart-define=QR_TEST_PUBLIC_KEY=$($qrStatus.PUBLISHABLE_KEY)"
    if ($LASTEXITCODE -ne 0) { throw 'Kiem thu QR/Home local chua dat.' }
} finally {
    $env:QR_TEST_ADMIN_KEY = $previousQrAdminKey
    Pop-Location
}
