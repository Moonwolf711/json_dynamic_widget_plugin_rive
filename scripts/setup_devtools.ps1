# One-time DevTools setup script
# Run this once to configure DevTools for headless operation

Write-Host "🚀 Setting up DevTools for headless operation..." -ForegroundColor Cyan

# Check if Dart SDK has DevTools
$devtoolsCheck = dart devtools --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ DevTools available: $devtoolsCheck" -ForegroundColor Green
} else {
    Write-Host "❌ DevTools not found. Make sure Flutter/Dart SDK is installed." -ForegroundColor Red
    exit 1
}

# Create scripts directory if it doesn't exist
if (-not (Test-Path "scripts")) {
    New-Item -ItemType Directory -Path "scripts" | Out-Null
    Write-Host "📁 Created scripts directory" -ForegroundColor Green
}

Write-Host ""
Write-Host "✅ Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Start your Flutter app:" -ForegroundColor Yellow
Write-Host "   flutter run -d windows" -ForegroundColor White
Write-Host ""
Write-Host "2. Look for VM Service URI in output (e.g., http://127.0.0.1:54321/xyz)" -ForegroundColor Yellow
Write-Host ""
Write-Host "3. Run DevTools headless:" -ForegroundColor Yellow
Write-Host "   .\scripts\devtools_headless.ps1 -VmServiceUri 'http://127.0.0.1:XXXXX/xyz'" -ForegroundColor White
Write-Host ""
Write-Host "4. Tail the log:" -ForegroundColor Yellow
Write-Host "   Get-Content devtools.log -Wait" -ForegroundColor White

