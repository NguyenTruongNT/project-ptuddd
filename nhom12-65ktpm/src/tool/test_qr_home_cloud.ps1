# Chỉ chạy chủ động trên Cloud development được nhóm trưởng cho phép.
# Script không deploy migration, không dùng dữ liệu demo có sẵn để kiểm thử ghi.
$ErrorActionPreference = 'Stop'
$qrCloudDirectory = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$previousQrAdminKey = $env:QR_TEST_ADMIN_KEY
Push-Location -LiteralPath $qrCloudDirectory
try {
    $qrProjectRef = 'dacrjfgleursgtnzeoix'
    $qrConfig = Get-Content assets/config/supabase.public.json -Raw -Encoding UTF8 | ConvertFrom-Json
    $qrLinkedRef = (Get-Content supabase/.temp/project-ref -Raw).Trim()
    if ($qrConfig.SUPABASE_URL -ne "https://$qrProjectRef.supabase.co" -or $qrLinkedRef -ne $qrProjectRef) {
        throw 'Chi cho phep dung Cloud development da cau hinh va link.'
    }
    # Không in toàn bộ kết quả CLI: nó chứa key quản trị, chỉ giữ trong tiến trình.
    $savedQrPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $qrKeyRaw = & npx.cmd supabase@3.3.0 projects api-keys "--remote=$qrProjectRef" --reveal --output-format json 2>$null
    $qrKeyExit = $LASTEXITCODE
    $ErrorActionPreference = $savedQrPreference
    if ($qrKeyExit -ne 0) { throw 'Khong lay duoc credential kiem thu Cloud.' }
    $qrKeyResult = ($qrKeyRaw -join "`n") | ConvertFrom-Json
    $qrKeys = if ($qrKeyResult.keys) { $qrKeyResult.keys } else { $qrKeyResult }
    $env:QR_TEST_ADMIN_KEY = ($qrKeys | Where-Object { $_.name -eq 'service_role' } | Select-Object -First 1).api_key
    if (-not $env:QR_TEST_ADMIN_KEY) { throw 'Thieu credential quan tri cho fixture QA.' }
    $qrKeyRaw = $null
    $qrKeys = $null
    $qrKeyResult = $null
    & flutter test test/integration/qr_home_supabase_test.dart --no-pub --reporter expanded --dart-define=RUN_QR_HOME_CLOUD=true "--dart-define=QR_TEST_URL=$($qrConfig.SUPABASE_URL)" "--dart-define=QR_TEST_PUBLIC_KEY=$($qrConfig.SUPABASE_PUBLISHABLE_KEY)"
    if ($LASTEXITCODE -ne 0) { throw 'Kiem thu QR/Home Cloud chua dat; xem UUID fixture neu cleanup bao loi.' }
} finally {
    $env:QR_TEST_ADMIN_KEY = $previousQrAdminKey
    $qrKeyRaw = $null
    $qrKeys = $null
    $qrKeyResult = $null
    Pop-Location
}
