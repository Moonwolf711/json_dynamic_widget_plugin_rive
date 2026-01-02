# Stop DevTools processes gracefully

$ErrorActionPreference = "Continue"

function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

Write-ColorOutput Cyan "🛑 Stopping DevTools processes..."

# Find DevTools processes by PID file
$pidFiles = Get-ChildItem -Path . -Filter "*.pid" -ErrorAction SilentlyContinue | 
    Where-Object { $_.Name -like "*devtools*.pid" -or $_.Name -like "devtools.log.pid" }

foreach ($pidFile in $pidFiles) {
    $pid = Get-Content $pidFile.FullName -ErrorAction SilentlyContinue
    if ($pid) {
        try {
            $process = Get-Process -Id $pid -ErrorAction SilentlyContinue
            if ($process) {
                Stop-Process -Id $pid -Force
                Write-ColorOutput Green "✅ Stopped process $pid"
            }
        } catch {
            # Process already stopped
        }
        Remove-Item $pidFile.FullName -Force -ErrorAction SilentlyContinue
    }
}

# Also find by command line pattern
$dartProcesses = Get-Process -Name "dart" -ErrorAction SilentlyContinue | 
    Where-Object { 
        try {
            $cmdLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($_.Id)").CommandLine
            $cmdLine -like '*devtools*'
        } catch {
            $false
        }
    }

if ($dartProcesses) {
    $dartProcesses | ForEach-Object {
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        Write-ColorOutput Green "✅ Stopped DevTools process $($_.Id)"
    }
}

Write-ColorOutput Green "✅ Cleanup complete"

