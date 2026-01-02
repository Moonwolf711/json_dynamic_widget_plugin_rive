# Dev Tools Quick Start Guide

## 🚀 Quick Commands

### VS Code Tasks (Ctrl+Shift+P → "Tasks: Run Task")
- `flutter: analyze` - Run code analysis
- `flutter: format` - Format all Dart files
- `flutter: test` - Run tests
- `flutter: build windows` - Build Windows release
- `devtools: start headless` - Start DevTools monitoring
- `devtools: stop` - Stop DevTools processes

### PowerShell Scripts

#### Build Scripts
```powershell
# Build Windows release
.\scripts\build.ps1 -Platform windows -Mode release

# Build Android APK
.\scripts\build.ps1 -Platform apk -Mode release

# Build all platforms
.\scripts\build.ps1 -Platform all -Mode release -Clean

# Build with analysis
.\scripts\build.ps1 -Platform windows -Analyze
```

#### Test Scripts
```powershell
# Run all tests
.\scripts\test.ps1

# Run with coverage
.\scripts\test.ps1 -Coverage

# Run specific test file
.\scripts\test.ps1 -TestFile "test/widget_test.dart"

# Watch mode
.\scripts\test.ps1 -Watch
```

#### DevTools Scripts
```powershell
# Enhanced DevTools (auto-detects VM URI)
.\scripts\devtools_enhanced.ps1

# Manual VM URI
.\scripts\devtools_enhanced.ps1 -VmServiceUri "http://127.0.0.1:54321/xyz"

# Stop DevTools
.\scripts\stop_devtools.ps1
```

## 📋 Development Workflow

### 1. Initial Setup
```powershell
# Get dependencies
flutter pub get

# Analyze code
flutter analyze

# Format code
dart format .
```

### 2. Development
```powershell
# Run app
flutter run -d windows

# In another terminal, start DevTools monitoring
.\scripts\devtools_enhanced.ps1

# Monitor logs
Get-Content devtools.log -Wait
```

### 3. Testing
```powershell
# Run tests
.\scripts\test.ps1

# Run with coverage
.\scripts\test.ps1 -Coverage
```

### 4. Building
```powershell
# Build Windows release
.\scripts\build.ps1 -Platform windows -Mode release

# Build Android APK
.\scripts\build.ps1 -Platform apk -Mode release
```

## 🔧 VS Code Integration

### Debugging
Press `F5` or use the debug panel to:
- Launch Windows app
- Launch Chrome app
- Attach to running app
- Profile performance

### Tasks
Press `Ctrl+Shift+B` or `Ctrl+Shift+P` → "Tasks: Run Task" to:
- Analyze code
- Format code
- Run tests
- Build projects
- Manage DevTools

## 📊 CI/CD

GitHub Actions automatically:
- ✅ Analyzes code on push/PR
- ✅ Runs tests
- ✅ Builds Windows and Android
- ✅ Uploads artifacts

## 🐛 Troubleshooting

### DevTools not connecting
1. Ensure Flutter app is running: `flutter run -d windows`
2. Check VM Service URI in Flutter output
3. Try manual URI: `.\scripts\devtools_enhanced.ps1 -VmServiceUri "http://127.0.0.1:XXXXX/xyz"`

### Build failures
1. Clean build: `flutter clean`
2. Get dependencies: `flutter pub get`
3. Check Flutter version: `flutter --version`

### Test failures
1. Run analysis: `flutter analyze`
2. Check test file syntax
3. Run single test: `.\scripts\test.ps1 -TestFile "test/widget_test.dart"`

## 📚 Additional Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart DevTools](https://docs.flutter.dev/tools/devtools)
- [VS Code Flutter Extension](https://marketplace.visualstudio.com/items?itemName=Dart-Code.flutter)

