# Kiểm tra nền tảng Flutter dùng chung cho cả nhóm StudyShare.
# Script KHÔNG thay đổi database, KHÔNG push Git, KHÔNG triển khai backend.
param(
    [switch]$Database,
    [switch]$AndroidBuild
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot trỏ tới thư mục src/tool, nên lấy thư mục cha là src.
$srcDirectory = Split-Path -Parent $PSScriptRoot

function Invoke-Checked {
    param(
        [string]$Executable,
        [string[]]$Arguments
    )

    Write-Host ("`n> " + $Executable + ' ' + ($Arguments -join ' ')) -ForegroundColor Cyan
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Lenh that bai: $Executable $($Arguments -join ' ') (exit $LASTEXITCODE)"
    }
}

# Dừng ngay nếu máy chưa cài Flutter hoặc không tìm thấy project.
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Chua tim thay Flutter SDK trong PATH.'
}
if (-not (Test-Path (Join-Path $srcDirectory 'pubspec.yaml'))) {
    throw 'Khong tim thay pubspec.yaml; kiem tra duong dan project.'
}

Push-Location $srcDirectory
try {
    Invoke-Checked -Executable 'flutter' -Arguments @('pub', 'get')
    Invoke-Checked -Executable 'flutter' -Arguments @('analyze')
    Invoke-Checked -Executable 'flutter' -Arguments @('test')

    if ($Database) {
        # Chỉ kiểm tra; không tự chạy db reset vì lệnh đó xóa dữ liệu local.
        $npxCommand = if (Get-Command 'npx.cmd' -ErrorAction SilentlyContinue) {
            'npx.cmd'
        } else {
            'npx'
        }
        if (-not (Get-Command $npxCommand -ErrorAction SilentlyContinue)) {
            throw 'Chua tim thay Node.js/npm (npx).'
        }
        Invoke-Checked -Executable $npxCommand -Arguments @('supabase', 'status')
        Invoke-Checked -Executable $npxCommand -Arguments @('supabase', 'test', 'db')
        Invoke-Checked -Executable $npxCommand -Arguments @('supabase', 'db', 'lint')
    }

    if ($AndroidBuild) {
        # Tạo APK debug để kiểm tra compile; file APK được .gitignore bỏ qua.
        Invoke-Checked -Executable 'flutter' -Arguments @('build', 'apk', '--debug')
    }

    Write-Host "`nHoan tat cac kiem tra da chon." -ForegroundColor Green
} finally {
    Pop-Location
}
