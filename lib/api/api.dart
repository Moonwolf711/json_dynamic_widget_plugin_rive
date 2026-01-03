/// Flutter Viewer API - Export file
///
/// Usage:
/// ```dart
/// import 'api/api.dart';
///
/// // Check API health
/// final isHealthy = await FlutterViewerApi().checkHealth();
///
/// // Get widgets
/// final widgets = await FlutterViewerApi().getWidgets();
///
/// // Configure API URL
/// ApiConfig.setBaseUrl('http://your-server:8000');
/// ```
library;

export 'api_config.dart';
export 'api_service.dart';
export 'models.dart';
