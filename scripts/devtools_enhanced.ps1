# Enhanced DevTools Headless Runner
# Auto-detects VM Service URI and provides robust error handling

param(
    [string]$VmServiceUri = "",
    [string]$LogFile = "devtools.log",
    [int]$MaxLogSizeMB = 10,
    [switch]$AutoDetect = $true
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

function Test-FlutterRunning {
    $flutterProcesses = Get-Process -Name "flutter" -ErrorAction SilentlyContinue
    return $flutterProcesses.Count -gt 0
}

function Get-VmServiceUri {
    Write-ColorOutput Cyan "🔍 Auto-detecting VM Service URI..."
    
    # Check if Flutter is running
    if (-not (Test-FlutterRunning)) {
        Write-ColorOutput Yellow "⚠️  Flutter app not detected. Start it first with:"
        Write-ColorOutput White "   flutter run -d windows"
        return $null
    }
    
    # Try to extract URI from common Flutter output locations
    $possibleUris = @()
    
    # Check for Flutter process output (limited on Windows)
    # Alternative: Parse from known Flutter ports
    $commonPorts = @(54321, 54322, 54323, 54324, 54325)
    
    foreach ($port in $commonPorts) {
        $testUri = "http://127.0.0.1:$port"
        try {
            $response = Invoke-WebRequest -Uri "$testUri/ws" -Method GET -TimeoutSec 1 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 400) {
                $possibleUris += $testUri
            }
        } catch {
            # Port not active, continue
        }
    }
    
    if ($possibleUris.Count -eq 0) {
        Write-ColorOutput Yellow "⚠️  Could not auto-detect VM Service URI."
        Write-ColorOutput Yellow "   Please provide it manually:"
        Write-ColorOutput White "   .\scripts\devtools_enhanced.ps1 -VmServiceUri 'http://127.0.0.1:XXXXX/xyz'"
        return $null
    }
    
    Write-ColorOutput Green "✅ Found VM Service URI: $($possibleUris[0])"
    return $possibleUris[0]
}

function Rotate-LogFile {
    param([string]$LogPath, [int]$MaxSizeMB)
    
    if (Test-Path $LogPath) {
        $file = Get-Item $LogPath
        $sizeMB = [math]::Round($file.Length / 1MB, 2)
        
        if ($sizeMB -gt $MaxSizeMB) {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $rotatedPath = "$LogPath.$timestamp"
            Move-Item $LogPath $rotatedPath -Force
            Write-ColorOutput Yellow "📦 Rotated log file (${sizeMB}MB) to $rotatedPath"
        }
    }
}

function Stop-DevToolsProcesses {
    Write-ColorOutput Cyan "🛑 Stopping existing DevTools processes..."
    $processes = Get-Process -Name "dart" -ErrorAction SilentlyContinue | 
        Where-Object { $_.CommandLine -like '*devtools*' }
    
    if ($processes) {
        $processes | Stop-Process -Force
        Write-ColorOutput Green "✅ Stopped $($processes.Count) DevTools process(es)"
    }
}

function Start-DevToolsHeadless {
    param([string]$Uri, [string]$Log)
    
    # Rotate log if needed
    Rotate-LogFile -LogPath $Log -MaxSizeMB $MaxLogSizeMB
    
    # Stop any existing DevTools processes
    Stop-DevToolsProcesses
    
    Write-ColorOutput Cyan "🚀 Starting DevTools headless..."
    Write-ColorOutput Green "📡 VM Service URI: $Uri"
    Write-ColorOutput Green "📝 Log file: $Log"
    
    # Start DevTools in background
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "dart"
    $processInfo.Arguments = "devtools --machine --no-launch-browser $Uri"
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    
    # Redirect output to log file
    $stdout = [System.IO.StreamWriter]::new($Log, $true)
    $stderr = [System.IO.StreamWriter]::new("${Log}.error", $true)
    
    $process.add_OutputDataReceived({
        param($sender, $e)
        if ($e.Data) {
            $stdout.WriteLine($e.Data)
            $stdout.Flush()
        }
    })
    
    $process.add_ErrorDataReceived({
        param($sender, $e)
        if ($e.Data) {
            $stderr.WriteLine($e.Data)
            $stderr.Flush()
        }
    })
    
    $process.Start() | Out-Null
    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()
    
    # Wait a moment to check if it started successfully
    Start-Sleep -Seconds 2
    
    if ($process.HasExited -and $process.ExitCode -ne 0) {
        Write-ColorOutput Red "❌ DevTools failed to start. Check ${Log}.error for details."
        $stdout.Close()
        $stderr.Close()
        return $null
    }
    
    Write-ColorOutput Green "✅ DevTools started successfully (PID: $($process.Id))"
    
    # Save process ID for cleanup
    $process.Id | Out-File "${Log}.pid" -Encoding ASCII
    
    $stdout.Close()
    $stderr.Close()
    
    return $process
}

# Main execution
Write-ColorOutput Cyan "🔧 Enhanced DevTools Headless Setup"
Write-ColorOutput Cyan "===================================="
Write-Host ""

# Determine VM Service URI
if ([string]::IsNullOrEmpty($VmServiceUri)) {
    if ($AutoDetect) {
        $VmServiceUri = Get-VmServiceUri
        if ([string]::IsNullOrEmpty($VmServiceUri)) {
            exit 1
        }
    } else {
        Write-ColorOutput Yellow "⚠️  VM Service URI not provided and auto-detect disabled."
        Write-ColorOutput Yellow "   Usage: .\scripts\devtools_enhanced.ps1 -VmServiceUri 'http://127.0.0.1:XXXXX/xyz'"
        exit 1
    }
}

# Validate URI format
if (-not $VmServiceUri -match '^https?://') {
    Write-ColorOutput Red "❌ Invalid VM Service URI format: $VmServiceUri"
    exit 1
}

# Start DevTools
$process = Start-DevToolsHeadless -Uri $VmServiceUri -Log $LogFile

if ($null -eq $process) {
    exit 1
}

Write-Host ""
Write-ColorOutput Cyan "📊 Monitor the log:"
Write-ColorOutput White "   Get-Content $LogFile -Wait"
Write-Host ""
Write-ColorOutput Cyan "🛑 Stop DevTools:"
Write-ColorOutput White "   Get-Process -Id $($process.Id) | Stop-Process"
Write-Host ""
Write-ColorOutput Cyan "   Or use: .\scripts\stop_devtools.ps1"
Write-Host ""

