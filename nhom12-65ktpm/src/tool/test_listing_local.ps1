param([switch]$IncludeSharedContracts)
# Chỉ local. Không truyền service key vào Flutter defines hoặc log.
$ErrorActionPreference = 'Stop'
$listingTestDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$previousListingAdminKey = $env:LISTING_TEST_ADMIN_KEY
$harnessInstalled = $false
$previousOutputEncoding = $OutputEncoding
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
    if ($IncludeSharedContracts) {
        # Chỉ cài harness trên container local đã biết; không gọi CLI --linked/--remote.
        $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
        Get-Content supabase/test_support/listing_shared_rpc.sql -Raw -Encoding utf8 |
            & docker exec -i supabase_db_src psql -U postgres -d postgres -v ON_ERROR_STOP=1
        if ($LASTEXITCODE -ne 0) { throw 'Khong cai duoc harness local.' }
        $harnessInstalled = $true
    }
    $env:LISTING_TEST_ADMIN_KEY = $listingStatus.SERVICE_ROLE_KEY
    if (-not $env:LISTING_TEST_ADMIN_KEY) { $env:LISTING_TEST_ADMIN_KEY = $listingStatus.SECRET_KEY }
    & flutter test test/integration/listing_supabase_test.dart --no-pub --reporter expanded --dart-define=RUN_LISTING_SUPABASE=true "--dart-define=RUN_LISTING_SHARED=$($IncludeSharedContracts.IsPresent.ToString().ToLowerInvariant())" "--dart-define=LISTING_TEST_URL=$($listingStatus.API_URL)" "--dart-define=LISTING_TEST_PUBLIC_KEY=$($listingStatus.PUBLISHABLE_KEY)"
    if ($LASTEXITCODE -ne 0) { throw 'Kiem thu Listing local chua dat.' }
} finally {
    $env:LISTING_TEST_ADMIN_KEY = $previousListingAdminKey
    $cleanupExit = 0
    if ($harnessInstalled) {
        Get-Content supabase/test_support/listing_shared_rpc_cleanup.sql -Raw -Encoding utf8 |
            & docker exec -i supabase_db_src psql -U postgres -d postgres -v ON_ERROR_STOP=1
        $cleanupExit = $LASTEXITCODE
    }
    $OutputEncoding = $previousOutputEncoding
    Pop-Location
    # Không báo PASS khi còn để lại endpoint test trong local.
    if ($cleanupExit -ne 0) { throw 'Can don hai RPC harness local theo file cleanup.' }
}
