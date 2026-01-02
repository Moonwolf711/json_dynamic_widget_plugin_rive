# DevTools Headless Setup

Stream live Rive data to AI without touching a browser.

## Quick Setup (10 seconds)

### 1. Run setup script
```powershell
.\scripts\setup_devtools.ps1
```

### 2. Start Flutter app
```powershell
flutter run -d windows
```

Look for VM Service URI in output (e.g., `http://127.0.0.1:54321/xyz`)

### 3. Start DevTools headless
```powershell
.\scripts\devtools_headless.ps1 -VmServiceUri "http://127.0.0.1:XXXXX/xyz"
```

### 4. Tail the log
```powershell
Get-Content devtools.log -Wait
```

## What You'll See

The log streams JSON events:
```json
{"event": "flutter.frame", "timestamp": 1234567890, "duration": 0.033}
{"event": "input.update", "name": "lipShape", "value": 2, "window": 1}
{"event": "roast.start", "window": 1, "path": "video.mp4"}
{"event": "roast.complete", "window": 1}
```

## Code Integration

The `_roast()` function automatically logs Rive events:
- `roast.start` - When roast begins
- `input.update` - When lipShape changes (value 2 = "ah" sound)
- `roast.complete` - When roast finishes
- `roast.error` - If something breaks

## AI Integration

Add this to your AI monitoring loop:
```dart
if (rive.inputs['lipShape']?.value == 2) {
  whisper('Terry is saying ah, advance mouth 2 frames');
}
```

Claude parses the stream, whispers back - you never look at DevTools.

## Troubleshooting

- **VM Service URI not found**: Make sure Flutter app is running first
- **No log output**: Check that DevTools connected successfully
- **Empty log**: Verify VM Service URI is correct

## Stop DevTools

```powershell
Get-Process | Where-Object {$_.CommandLine -like '*devtools*'} | Stop-Process
```

