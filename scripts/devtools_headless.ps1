# DevTools Headless Runner - Streams live Rive data to devtools.log
# Usage: Run this AFTER starting flutter run -d windows
# It will auto-detect the VM service URI and start streaming

param(
    [string]$VmServiceUri = "",
    [string]$LogFile = "devtools.log"
)

Write-Host "🔧 DevTools Headless Setup" -ForegroundColor Cyan

# If no URI provided, try to detect from Flutter output
if ([string]::IsNullOrEmpty($VmServiceUri)) {
    Write-Host "⚠️  VM Service URI not provided. Run Flutter first:" -ForegroundColor Yellow
    Write-Host "   flutter run -d windows" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Then run this script with:" -ForegroundColor Yellow
    Write-Host "   .\scripts\devtools_headless.ps1 -VmServiceUri 'http://127.0.0.1:XXXXX/xyz'" -ForegroundColor Yellow
    exit 1
}

Write-Host "📡 Connecting to VM Service: $VmServiceUri" -ForegroundColor Green
Write-Host "📝 Logging to: $LogFile" -ForegroundColor Green

# Start DevTools in machine mode (JSON output)
# Note: --machine mode outputs JSON, but we'll redirect to log file
dart devtools --machine --no-launch-browser $VmServiceUri > $LogFile 2>&1 &

Write-Host "✅ DevTools headless started in background" -ForegroundColor Green
Write-Host "📊 Tail the log: Get-Content $LogFile -Wait" -ForegroundColor Cyan
Write-Host ""
Write-Host "To stop: Get-Process | Where-Object {$_.CommandLine -like '*devtools*'} | Stop-Process" -ForegroundColor Yellow

