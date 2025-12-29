# Hot Reload Helper for WFL Flutter App
# Triggers hot reload via VM Service API

$vmServiceUrl = Get-Content "C:\wfl\.flutter_vm_url" -ErrorAction SilentlyContinue
if (-not $vmServiceUrl) {
    Write-Host "No VM service URL found. Is the app running?"
    exit 1
}

# Convert http to ws for websocket connection
$wsUrl = $vmServiceUrl -replace "http://", "ws://" -replace "=$", "=/ws"

Write-Host "Triggering hot reload on $wsUrl..."

# Use PowerShell to send reload command
try {
    $ws = New-Object System.Net.WebSockets.ClientWebSocket
    $ct = New-Object System.Threading.CancellationToken
    $ws.ConnectAsync($wsUrl, $ct).Wait()

    # Send hot reload request
    $msg = '{"jsonrpc":"2.0","id":"1","method":"reloadSources","params":{"isolateId":"isolates/0"}}'
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($msg)
    $segment = New-Object System.ArraySegment[byte] -ArgumentList @(,$bytes)
    $ws.SendAsync($segment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $ct).Wait()

    Write-Host "Hot reload triggered!"
    $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "", $ct).Wait()
} catch {
    Write-Host "Error: $_"
}
