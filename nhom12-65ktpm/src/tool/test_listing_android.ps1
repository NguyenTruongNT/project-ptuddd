param([string]$Device = 'emulator-5554')
# Account local dùng một lần. Service key chỉ ở host, không vào APK/Flutter define.
$ErrorActionPreference = 'Stop'
$listingAndroidDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Push-Location -LiteralPath $listingAndroidDirectory
$fixtureUser = $null
try {
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $statusOutput = & npx.cmd supabase@3.3.0 status -o json 2>$null
    $statusExit = $LASTEXITCODE
    $ErrorActionPreference = $savedPreference
    if ($statusExit -ne 0) { throw 'Supabase local chua chay.' }
    $status = ($statusOutput -join "`n") | ConvertFrom-Json
    if ($status.API_URL -ne 'http://127.0.0.1:54321') { throw 'Chi cho phep localhost.' }
    $adminKey = $status.SERVICE_ROLE_KEY
    if (-not $adminKey) { $adminKey = $status.SECRET_KEY }
    $headers = @{ apikey = $adminKey; Authorization = "Bearer $adminKey" }
    $fixtureSuffix = [guid]::NewGuid().ToString('N')
    $fixtureEmail = "listing-android-$fixtureSuffix@example.test"
    $fixturePassword = "ListingAndroid-$fixtureSuffix!Aa1"
    $fixtureBody = @{ email = $fixtureEmail; password = $fixturePassword; email_confirm = $true } | ConvertTo-Json
    $fixtureUser = Invoke-RestMethod -Method Post -Uri "$($status.API_URL)/auth/v1/admin/users" -Headers $headers -ContentType 'application/json' -Body $fixtureBody
    $sdkAdb = Join-Path $env:LOCALAPPDATA 'Android\sdk\platform-tools\adb.exe'
    & $sdkAdb -s $Device reverse tcp:54321 tcp:54321
    if ($LASTEXITCODE -ne 0) { throw 'Khong reverse duoc Supabase local vao emulator.' }
    # Gradle có cảnh báo stderr; PowerShell không được coi warning là lỗi dừng script.
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    & flutter test integration_test/listing_android_test.dart -d $Device --reporter expanded "--dart-define=SUPABASE_URL=$($status.API_URL)" "--dart-define=SUPABASE_PUBLISHABLE_KEY=$($status.PUBLISHABLE_KEY)" "--dart-define=LISTING_ANDROID_EMAIL=$fixtureEmail" "--dart-define=LISTING_ANDROID_PASSWORD=$fixturePassword"
    $androidTestExit = $LASTEXITCODE
    $ErrorActionPreference = $savedPreference
    if ($androidTestExit -ne 0) { throw 'Kiem thu Listing Android chua dat.' }
} finally {
    if ($fixtureUser -and $fixtureUser.id) {
        # Chỉ dọn dữ liệu của account vừa tạo, không reset dữ liệu người dùng khác.
        $fixtureMaterials = Invoke-RestMethod -Uri "$($status.API_URL)/rest/v1/materials?owner_id=eq.$($fixtureUser.id)&select=id" -Headers $headers
        foreach ($m in $fixtureMaterials) {
            $fixtureListings = Invoke-RestMethod -Uri "$($status.API_URL)/rest/v1/listings?material_id=eq.$($m.id)&select=id" -Headers $headers
            foreach ($l in $fixtureListings) {
                Invoke-RestMethod -Method Delete -Uri "$($status.API_URL)/rest/v1/listing_snapshot_images?listing_id=eq.$($l.id)" -Headers $headers | Out-Null
                Invoke-RestMethod -Method Delete -Uri "$($status.API_URL)/rest/v1/listings?id=eq.$($l.id)" -Headers $headers | Out-Null
            }
            Invoke-RestMethod -Method Delete -Uri "$($status.API_URL)/rest/v1/material_images?material_id=eq.$($m.id)" -Headers $headers | Out-Null
        }
        $fixtureUploads = Invoke-RestMethod -Uri "$($status.API_URL)/rest/v1/material_image_uploads?actor_id=eq.$($fixtureUser.id)&select=storage_path" -Headers $headers
        if ($fixtureUploads) {
            $removeBody = @{ prefixes = @($fixtureUploads | ForEach-Object { $_.storage_path }) } | ConvertTo-Json
            Invoke-RestMethod -Method Delete -Uri "$($status.API_URL)/storage/v1/object/studyshare-material-images" -Headers $headers -ContentType 'application/json' -Body $removeBody | Out-Null
        }
        Invoke-RestMethod -Method Delete -Uri "$($status.API_URL)/rest/v1/material_image_uploads?actor_id=eq.$($fixtureUser.id)" -Headers $headers | Out-Null
        Invoke-RestMethod -Method Delete -Uri "$($status.API_URL)/rest/v1/command_receipts?actor_id=eq.$($fixtureUser.id)" -Headers $headers | Out-Null
        Invoke-RestMethod -Method Delete -Uri "$($status.API_URL)/rest/v1/materials?owner_id=eq.$($fixtureUser.id)" -Headers $headers | Out-Null
        Invoke-RestMethod -Method Delete -Uri "$($status.API_URL)/auth/v1/admin/users/$($fixtureUser.id)" -Headers $headers | Out-Null
    }
    Pop-Location
}
