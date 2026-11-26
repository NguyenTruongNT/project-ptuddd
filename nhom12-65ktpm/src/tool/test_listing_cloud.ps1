# Smoke test development cloud, chỉ chạy chủ động; không dùng trong flutter test/CI.
# Secret quản trị chỉ nằm trong tiến trình PowerShell, không in ra và không vào Flutter.
$ErrorActionPreference = 'Stop'
$cloudTestDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Push-Location -LiteralPath $cloudTestDirectory
$createdUsers = [Collections.Generic.List[string]]::new()
try {
    $config = Get-Content assets/config/supabase.public.json -Raw | ConvertFrom-Json
    $projectRef = (Get-Content supabase/.temp/project-ref -Raw).Trim()
    if ($projectRef -ne 'dacrjfgleursgtnzeoix' -or $config.SUPABASE_URL -ne "https://$projectRef.supabase.co") {
        throw 'Smoke test chi ho tro dung project development da cau hinh.'
    }
    $savedPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $keyOutput = & npx.cmd supabase@3.3.0 projects api-keys --reveal --output json 2>$null
    $keyExit = $LASTEXITCODE
    $ErrorActionPreference = $savedPreference
    if ($keyExit -ne 0) { throw 'Khong lay duoc key quan tri cho smoke test.' }
    $keys = ($keyOutput -join "`n") | ConvertFrom-Json
    $adminKey = ($keys | Where-Object { $_.name -eq 'service_role' } | Select-Object -First 1).api_key
    $keyOutput = $null
    $keys = $null
    if (-not $adminKey) { throw 'Khong co service_role cho fixture cloud.' }
    $adminHeaders = @{ apikey = $adminKey; Authorization = "Bearer $adminKey" }
    $publicHeaders = @{ apikey = $config.SUPABASE_PUBLISHABLE_KEY }
    $baseUrl = $config.SUPABASE_URL
    $suffix = [Guid]::NewGuid().ToString('N')

    function Invoke-CloudRequest($method, $path, $headers, $body = $null, $contentType = 'application/json') {
        $requestArgs = @{ Method = $method; Uri = "$baseUrl$path"; Headers = $headers; ContentType = $contentType }
        if ($null -ne $body) { $requestArgs.Body = $body }
        try { Invoke-RestMethod @requestArgs }
        catch {
            # Không đưa request headers/token hoặc payload thô vào thông báo lỗi.
            $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { 'network' }
            throw "Cloud smoke: $method $path HTTP $status"
        }
    }
    function Invoke-ListingRpc($name, $payload, $headers, [string]$expectedError = '') {
        try {
            $value = Invoke-RestMethod -Method Post -Uri "$baseUrl/rest/v1/rpc/$name" -Headers $headers -ContentType 'application/json' -Body ($payload | ConvertTo-Json -Depth 12 -Compress)
        } catch {
            $raw = $_.ErrorDetails.Message
            if (-not $raw -and $_.Exception.Response) {
                $reader = [IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
                try { $raw = $reader.ReadToEnd() } finally { $reader.Dispose() }
            }
            $domain = $null
            try { $domain = ($raw | ConvertFrom-Json).message } catch { }
            if ($expectedError -and $domain -eq $expectedError) { return }
            throw "Cloud smoke: RPC $name khong tra ket qua mong doi."
        }
        if ($expectedError) { throw "Cloud smoke: RPC $name da nhan dau vao phai bi chan." }
        # Windows PowerShell 5 có thể giữ JSON null ở dạng chuỗi, cần chuẩn hóa.
        if ($value -is [string] -and $value.Trim() -eq 'null') { return $null }
        return $value
    }
    function Assert-Cloud($condition, [string]$message) {
        if (-not $condition) { throw "Cloud smoke: $message" }
    }

    # Hai tài khoản dùng một lần; chỉ UUID do script tạo mới được dùng khi dọn fixture.
    $sessions = @()
    foreach ($label in @('a', 'b')) {
        $email = "listing-cloud-$label-$suffix@example.test"
        $password = "ListingCloud-$suffix!Aa1"
        $user = Invoke-CloudRequest Post '/auth/v1/admin/users' $adminHeaders (@{ email=$email; password=$password; email_confirm=$true } | ConvertTo-Json)
        $createdUsers.Add($user.id)
        $session = Invoke-CloudRequest Post '/auth/v1/token?grant_type=password' $publicHeaders (@{ email=$email; password=$password } | ConvertTo-Json)
        $sessions += @{ apikey=$config.SUPABASE_PUBLISHABLE_KEY; Authorization="Bearer $($session.access_token)" }
    }
    $a = $sessions[0]
    $b = $sessions[1]
    $materialPayload = @{ title="Listing cloud smoke $suffix"; subject='Toan'; condition='Tot'; image_ids=@() }
    $material = Invoke-ListingRpc save_material @{ p_payload=$materialPayload; p_idempotency_key="smoke-material-$suffix" } $a
    $draft = Invoke-ListingRpc save_listing @{ p_action='draft'; p_payload=@{offer_type='SELL'}; p_idempotency_key="smoke-draft-$suffix"; p_material_id=$material.id; p_expected_material_revision=$material.revision } $a
    Assert-Cloud ($draft.data.status -eq 'DRAFT') 'Khong luu duoc SELL draft thieu gia.'
    $command = @{ p_action='publish'; p_payload=@{offer_type='SELL'; asking_price_vnd=100000}; p_idempotency_key="smoke-no-image-$suffix"; p_listing_id=$draft.data.id; p_expected_revision=$draft.server_revision; p_expected_material_revision=$material.revision }
    Invoke-ListingRpc save_listing $command $a 'INVALID_INPUT'
    $command.p_payload.asking_price_vnd = 0
    $command.p_idempotency_key = "smoke-invalid-price-$suffix"
    Invoke-ListingRpc save_listing $command $a 'INVALID_INPUT'

    # Dùng ảnh fixture JPEG thật đã có trong test, đi qua Storage và Edge verify.
    $fixtureText = Get-Content test/support/material_image_fixtures.dart -Raw
    $fixtureMatch = [regex]::Match($fixtureText, "materialJpegFixture\(\) => base64Decode\(\s*'([^']+)'")
    Assert-Cloud $fixtureMatch.Success 'Khong tim thay fixture JPEG.'
    $imageBytes = [Convert]::FromBase64String($fixtureMatch.Groups[1].Value)
    $upload = Invoke-ListingRpc prepare_material_image @{p_mime_type='image/jpeg'; p_byte_size=$imageBytes.Length; p_material_id=$material.id} $a
    Invoke-CloudRequest Post "/storage/v1/object/studyshare-material-images/$($upload.storage_path)" $a $imageBytes 'image/jpeg' | Out-Null
    Invoke-CloudRequest Post '/functions/v1/verify-material-image' $a (@{image_id=$upload.id} | ConvertTo-Json) | Out-Null
    $materialPayload.image_ids = @($upload.id)
    $material = Invoke-ListingRpc save_material @{p_payload=$materialPayload; p_idempotency_key="smoke-attach-$suffix"; p_material_id=$material.id; p_expected_revision=$material.revision} $a
    $command.p_payload.asking_price_vnd = 100000
    $command.p_idempotency_key = "smoke-publish-$suffix"
    $command.p_expected_material_revision = $material.revision
    $published = Invoke-ListingRpc save_listing $command $a
    Assert-Cloud ($published.data.status -eq 'PUBLISHED') 'Khong cong bo duoc SELL.'
    $retry = Invoke-ListingRpc save_listing $command $a
    Assert-Cloud ($retry.command_id -eq $published.command_id) 'Retry tao receipt moi.'
    $details = Invoke-ListingRpc get_published_listing @{p_listing_id=$published.data.id} $b
    Assert-Cloud ($details.title -eq $materialPayload.title -and $details.is_requestable) 'B khong doc duoc tin cong khai.'
    $search = Invoke-ListingRpc search_published_listings @{p_keyword=$suffix} $b
    Assert-Cloud (@($search.items | Where-Object { $_.id -eq $published.data.id }).Count -eq 1) 'Tin khong co trong repository Kham pha.'
    $visibility = @{p_action='hide'; p_payload=@{}; p_listing_id=$published.data.id; p_expected_revision=$published.server_revision; p_idempotency_key="smoke-hide-$suffix"}
    Invoke-ListingRpc save_listing $visibility $b 'FORBIDDEN'
    $hidden = Invoke-ListingRpc save_listing $visibility $a
    Assert-Cloud ($hidden.data.status -eq 'HIDDEN') 'Khong an duoc tin.'
    $hiddenRead = Invoke-ListingRpc get_published_listing @{p_listing_id=$published.data.id} $b
    Assert-Cloud ($null -eq $hiddenRead) 'Tin an van doc duoc qua Discovery.'
    $visibility.p_action = 'show'
    $visibility.p_expected_revision = $hidden.server_revision
    $visibility.p_expected_material_revision = $material.revision
    $visibility.p_idempotency_key = "smoke-show-$suffix"
    $shown = Invoke-ListingRpc save_listing $visibility $a
    Assert-Cloud ($shown.data.status -eq 'PUBLISHED') 'Khong hien lai duoc tin.'
    Write-Output 'PASS cloud: Auth A/B, anh Storage + Edge verify, draft, validation, publish, retry, Discovery, quyen, hide/show.'
} finally {
    foreach ($actorId in $createdUsers) {
        # Không dọn theo prefix hoặc danh sách tài khoản có sẵn; chỉ đúng UUID vừa tạo.
        $materials = Invoke-CloudRequest Get "/rest/v1/materials?owner_id=eq.$actorId&select=id" $adminHeaders
        foreach ($m in $materials) {
            $listings = Invoke-CloudRequest Get "/rest/v1/listings?material_id=eq.$($m.id)&select=id" $adminHeaders
            foreach ($l in $listings) {
                Invoke-CloudRequest Delete "/rest/v1/listing_snapshot_images?listing_id=eq.$($l.id)" $adminHeaders | Out-Null
                Invoke-CloudRequest Delete "/rest/v1/listings?id=eq.$($l.id)" $adminHeaders | Out-Null
            }
            Invoke-CloudRequest Delete "/rest/v1/material_images?material_id=eq.$($m.id)" $adminHeaders | Out-Null
        }
        $uploads = Invoke-CloudRequest Get "/rest/v1/material_image_uploads?actor_id=eq.$actorId&select=storage_path" $adminHeaders
        if ($uploads) {
            Invoke-CloudRequest Delete '/storage/v1/object/studyshare-material-images' $adminHeaders (@{prefixes=@($uploads | ForEach-Object {$_.storage_path})} | ConvertTo-Json) | Out-Null
        }
        Invoke-CloudRequest Delete "/rest/v1/material_image_uploads?actor_id=eq.$actorId" $adminHeaders | Out-Null
        Invoke-CloudRequest Delete "/rest/v1/command_receipts?actor_id=eq.$actorId" $adminHeaders | Out-Null
        Invoke-CloudRequest Delete "/rest/v1/materials?owner_id=eq.$actorId" $adminHeaders | Out-Null
        Invoke-CloudRequest Delete "/auth/v1/admin/users/$actorId" $adminHeaders | Out-Null
    }
    $adminKey = $null
    $adminHeaders = $null
    $sessions = $null
    Pop-Location
}
