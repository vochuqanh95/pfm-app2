param(
    [string]$AppId = "com.example.personal_finance_management",
    [string]$RemoteDir = "app_flutter",
    [string]$LocalDir = "exports"
)

Write-Host "[EXPORT_PULL] Using app id: $AppId"

# Tạo thư mục exports nếu chưa có
if (-not (Test-Path $LocalDir)) {
    New-Item -ItemType Directory -Path $LocalDir | Out-Null
}

# 1) Lấy tên file CSV mới nhất bên trong thư mục app_flutter
$lsCmd = "run-as $AppId sh -c 'cd $RemoteDir && ls -t transactions_*.csv 2>/dev/null | head -n 1'"

Write-Host "[EXPORT_PULL] Running: adb shell $lsCmd"
$latest = adb shell $lsCmd | ForEach-Object { $_.Trim() }

if (-not $latest) {
    Write-Host "[EXPORT_PULL] Không tìm thấy file transactions_*.csv trong $RemoteDir"
    Write-Host "[EXPORT_PULL] Gợi ý: kiểm tra log Flutter [EXPORT] xem đường dẫn export có đúng app_flutter không."
    exit 1
}

Write-Host "[EXPORT_PULL] Found latest export: $latest"

# 2) Dùng adb exec-out + run-as + cat để stream file ra PC
$localPath = Join-Path $LocalDir $latest
Write-Host "[EXPORT_PULL] Pulling to $localPath ..."

# Lệnh chạy trên thiết bị: run-as <appId> cat app_flutter/<file>
$remoteCmd = "run-as $AppId cat $RemoteDir/$latest"

# Trong PowerShell: adb exec-out <remoteCmd> > localPath
& adb exec-out $remoteCmd > $localPath

# 3) Mở bằng VS Code (nếu có lệnh 'code')
Write-Host "[EXPORT_PULL] Opening in VS Code (nếu khả dụng) ..."
try {
    code $localPath
} catch {
    Write-Host "[EXPORT_PULL] Không mở được bằng 'code', hãy mở file này bằng tay:"
    Write-Host "  $localPath"
}

Write-Host "[EXPORT_PULL] Done ✅"
