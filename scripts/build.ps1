# Build automation script for WFL Viewer
# Supports Windows, Android APK, and release builds

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("windows", "apk", "appbundle", "ios", "all")]
    [string]$Platform = "windows",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("debug", "profile", "release")]
    [string]$Mode = "release",
    
    [switch]$Clean = $false,
    [switch]$GetDependencies = $true,
    [switch]$Analyze = $false
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

function Invoke-FlutterCommand {
    param([string[]]$Arguments)
    
    Write-ColorOutput Cyan "▶ flutter $($Arguments -join ' ')"
    & flutter $Arguments
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput Red "❌ Flutter command failed"
        exit $LASTEXITCODE
    }
}

Write-ColorOutput Cyan "🔨 WFL Viewer Build Script"
Write-ColorOutput Cyan "=========================="
Write-Host ""
Write-ColorOutput Green "Platform: $Platform"
Write-ColorOutput Green "Mode: $Mode"
Write-Host ""

# Clean if requested
if ($Clean) {
    Write-ColorOutput Yellow "🧹 Cleaning build artifacts..."
    Invoke-FlutterCommand @("clean")
}

# Get dependencies
if ($GetDependencies) {
    Write-ColorOutput Yellow "📦 Getting dependencies..."
    Invoke-FlutterCommand @("pub", "get")
}

# Analyze code
if ($Analyze) {
    Write-ColorOutput Yellow "🔍 Analyzing code..."
    Invoke-FlutterCommand @("analyze")
}

# Build based on platform
switch ($Platform) {
    "windows" {
        Write-ColorOutput Yellow "🪟 Building Windows ($Mode)..."
        Invoke-FlutterCommand @("build", "windows", "--$Mode")
        Write-ColorOutput Green "✅ Windows build complete: build\windows\$Mode\runner\Release\wfl_viewer.exe"
    }
    "apk" {
        Write-ColorOutput Yellow "🤖 Building Android APK ($Mode)..."
        Invoke-FlutterCommand @("build", "apk", "--$Mode")
        Write-ColorOutput Green "✅ APK build complete: build\app\outputs\flutter-apk\app-$Mode.apk"
    }
    "appbundle" {
        Write-ColorOutput Yellow "📱 Building Android App Bundle ($Mode)..."
        Invoke-FlutterCommand @("build", "appbundle", "--$Mode")
        Write-ColorOutput Green "✅ App Bundle complete: build\app\outputs\bundle\release\app-release.aab"
    }
    "ios" {
        Write-ColorOutput Yellow "🍎 Building iOS ($Mode)..."
        Invoke-FlutterCommand @("build", "ios", "--$Mode", "--no-codesign")
        Write-ColorOutput Green "✅ iOS build complete"
    }
    "all" {
        Write-ColorOutput Yellow "🌍 Building all platforms..."
        
        # Windows
        Write-ColorOutput Yellow "🪟 Building Windows..."
        Invoke-FlutterCommand @("build", "windows", "--$Mode")
        
        # Android APK
        Write-ColorOutput Yellow "🤖 Building Android APK..."
        Invoke-FlutterCommand @("build", "apk", "--$Mode")
        
        Write-ColorOutput Green "✅ All builds complete"
    }
}

Write-Host ""
Write-ColorOutput Green "🎉 Build process completed successfully!"

