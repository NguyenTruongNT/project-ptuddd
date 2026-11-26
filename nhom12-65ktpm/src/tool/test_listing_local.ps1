# Chỉ local. Không truyền service key vào Flutter defines hoặc log.
$ErrorActionPreference = 'Stop'
$listingTestDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$previousListingAdminKey = $env:LISTING_TEST_ADMIN_KEY
Push-Location -LiteralPath $listingTestDirectory
try {
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $listingStatusOutput = & npx.cmd supabase@3.3.0 status -o json 2>$null
    $listingStatusExit = $LASTEXITCODE
    $ErrorActionPreference = $savedPreference
    if ($listingStatusExit -ne 0) { throw 'Supabase local chua chay.' }
    $listingStatus = ($listingStatusOutput -join "`n") | ConvertFrom-Json
    if ($listingStatus.API_URL -ne 'http://127.0.0.1:54321') { throw 'Chi cho phep local.' }
    $env:LISTING_TEST_ADMIN_KEY = $listingStatus.SERVICE_ROLE_KEY
    if (-not $env:LISTING_TEST_ADMIN_KEY) { $env:LISTING_TEST_ADMIN_KEY = $listingStatus.SECRET_KEY }
    & flutter test test/integration/listing_supabase_test.dart --no-pub --reporter expanded --dart-define=RUN_LISTING_SUPABASE=true "--dart-define=LISTING_TEST_URL=$($listingStatus.API_URL)" "--dart-define=LISTING_TEST_PUBLIC_KEY=$($listingStatus.PUBLISHABLE_KEY)"
    if ($LASTEXITCODE -ne 0) { throw 'Kiem thu Listing local chua dat.' }
} finally {
    $env:LISTING_TEST_ADMIN_KEY = $previousListingAdminKey
    Pop-Location
}
