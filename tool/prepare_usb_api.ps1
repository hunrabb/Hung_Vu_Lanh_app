param([string]$DeviceId = '3abb8353')
$ErrorActionPreference = 'Stop'
$sdkDirectory = if ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } elseif ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\sdk' }
$adbPath = Join-Path $sdkDirectory 'platform-tools\adb.exe'
if (-not (Test-Path -LiteralPath $adbPath)) { throw 'Không tìm thấy adb trong Android SDK.' }
& $adbPath -s $DeviceId get-state
if ($LASTEXITCODE -ne 0) { throw 'Điện thoại chưa kết nối/authorize USB debugging.' }
& $adbPath -s $DeviceId reverse tcp:3000 tcp:3000
if ($LASTEXITCODE -ne 0) { throw 'Không tạo được USB tunnel cổng 3000.' }
try {
    $response = Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:3000/api/branches' -TimeoutSec 5
    if ($response.StatusCode -ne 200) { throw 'API không trả HTTP200.' }
} catch {
    throw 'NestJS chưa sẵn sàng ở cổng3000. Chạy npm start trong ktgk/backend rồi F5 lại.'
}
Write-Host 'USB API ready: localhost:3000/api. Flutter USB profile uses this URL.'
