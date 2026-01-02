/// Flutter Viewer API Configuration
class ApiConfig {
  static String baseUrl = const String.fromEnvironment(
    'FLUTTER_VIEWER_API_URL',
    defaultValue: 'http://localhost:8000',
  );

  static void setBaseUrl(String url) {
    baseUrl = url;
  }

  static String get projectsUrl => '$baseUrl/projects';
  static String get widgetsUrl => '$baseUrl/widgets';
  static String get categoriesUrl => '$baseUrl/categories';
  static String get tagsUrl => '$baseUrl/tags';
}
