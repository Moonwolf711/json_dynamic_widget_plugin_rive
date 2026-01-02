# Start DevTools monitoring for Rive inputs
# This connects to Flutter's VM service and streams events

param(
    [string]$VmServiceUri = ""
)

Write-Host "🔧 DevTools Rive Monitor" -ForegroundColor Cyan

if ([string]::IsNullOrEmpty($VmServiceUri)) {
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "1. Start Flutter app: flutter run -d windows" -ForegroundColor White
    Write-Host "2. Look for VM Service URI in output" -ForegroundColor White
    Write-Host "3. Run: .\scripts\start_devtools_monitor.ps1 -VmServiceUri 'http://127.0.0.1:XXXXX/xyz'" -ForegroundColor White
    Write-Host ""
    Write-Host "Or use machine mode:" -ForegroundColor Yellow
    Write-Host "   dart devtools --machine --no-launch-browser $VmServiceUri > devtools.log" -ForegroundColor White
    exit 1
}

Write-Host "📡 Connecting to: $VmServiceUri" -ForegroundColor Green
Write-Host "📝 Streaming to: devtools.log" -ForegroundColor Green

# Start DevTools in machine mode (JSON output)
Start-Process -NoNewWindow -FilePath "dart" -ArgumentList "devtools", "--machine", "--no-launch-browser", $VmServiceUri -RedirectStandardOutput "devtools.log" -RedirectStandardError "devtools_error.log"

Write-Host ""
Write-Host "✅ DevTools monitor started" -ForegroundColor Green
Write-Host "📊 Tail log: Get-Content devtools.log -Wait" -ForegroundColor Cyan
Write-Host ""
Write-Host "The app logs Rive events automatically:" -ForegroundColor Yellow
Write-Host "  - roast.start" -ForegroundColor White
Write-Host "  - input.update (lipShape changes)" -ForegroundColor White
Write-Host "  - roast.complete" -ForegroundColor White

