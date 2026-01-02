# Test automation script

param(
    [switch]$Coverage = $false,
    [switch]$Watch = $false,
    [string]$TestFile = ""
)

$ErrorActionPreference = "Stop"

function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput Cyan "🧪 WFL Viewer Test Runner"
Write-ColorOutput Cyan "=========================="
Write-Host ""

$testArgs = @("test")

if ($Coverage) {
    Write-ColorOutput Yellow "📊 Running tests with coverage..."
    $testArgs += "--coverage"
}

if ($Watch) {
    Write-ColorOutput Yellow "👀 Running tests in watch mode..."
    $testArgs += "--watch"
}

if ($TestFile) {
    Write-ColorOutput Yellow "📄 Running specific test: $TestFile"
    $testArgs += $TestFile
}

Write-ColorOutput Cyan "▶ flutter $($testArgs -join ' ')"
& flutter $testArgs

if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput Red "❌ Tests failed"
    exit $LASTEXITCODE
}

if ($Coverage) {
    Write-Host ""
    Write-ColorOutput Green "📊 Coverage report generated: coverage/lcov.info"
    Write-ColorOutput Cyan "   View with: flutter test --coverage && genhtml coverage/lcov.info -o coverage/html"
}

Write-ColorOutput Green "✅ Tests completed successfully"

