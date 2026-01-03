import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'models.dart';

/// Service for communicating with Flutter Viewer API
class FlutterViewerApi {
  static final FlutterViewerApi _instance = FlutterViewerApi._internal();
  factory FlutterViewerApi() => _instance;
  FlutterViewerApi._internal();

  final http.Client _client = http.Client();

  // === Projects ===

  Future<List<Project>> getProjects({bool activeOnly = false}) async {
    final url = '${ApiConfig.projectsUrl}/?active_only=$activeOnly';
    final response = await _client.get(Uri.parse(url));
    _checkResponse(response);
    final List<dynamic> data = json.decode(response.body);
    return data.map((j) => Project.fromJson(j)).toList();
  }

  Future<Project> getProject(int id) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.projectsUrl}/$id'),
    );
    _checkResponse(response);
    return Project.fromJson(json.decode(response.body));
  }

  Future<Project> createProject({
    required String name,
    required String path,
    String? description,
    String? flutterVersion,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.projectsUrl}/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': name,
        'path': path,
        if (description != null) 'description': description,
        if (flutterVersion != null) 'flutter_version': flutterVersion,
      }),
    );
    _checkResponse(response);
    return Project.fromJson(json.decode(response.body));
  }

  // === Widgets ===

  Future<List<FlutterWidget>> getWidgets({
    int? projectId,
    int? categoryId,
    List<int>? tagIds,
    String? search,
  }) async {
    final params = <String, String>{};
    if (projectId != null) params['project_id'] = projectId.toString();
    if (categoryId != null) params['category_id'] = categoryId.toString();
    if (search != null) params['search'] = search;

    var url = '${ApiConfig.widgetsUrl}/';
    if (params.isNotEmpty) {
      url += '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    }
    if (tagIds != null && tagIds.isNotEmpty) {
      final tagParams = tagIds.map((id) => 'tag_ids=$id').join('&');
      url += params.isEmpty ? '?$tagParams' : '&$tagParams';
    }

    final response = await _client.get(Uri.parse(url));
    _checkResponse(response);
    final List<dynamic> data = json.decode(response.body);
    return data.map((j) => FlutterWidget.fromJson(j)).toList();
  }

  Future<FlutterWidget> getWidget(int id) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.widgetsUrl}/$id'),
    );
    _checkResponse(response);
    return FlutterWidget.fromJson(json.decode(response.body));
  }

  Future<FlutterWidget> createWidget({
    required String name,
    required String sourceCode,
    required int projectId,
    String? description,
    int? categoryId,
    List<int>? tagIds,
    bool isStateful = false,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.widgetsUrl}/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': name,
        'source_code': sourceCode,
        'project_id': projectId,
        if (description != null) 'description': description,
        if (categoryId != null) 'category_id': categoryId,
        if (tagIds != null) 'tag_ids': tagIds,
        'is_stateful': isStateful,
      }),
    );
    _checkResponse(response);
    return FlutterWidget.fromJson(json.decode(response.body));
  }

  Future<FlutterWidget> favoriteWidget(int id) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.widgetsUrl}/$id/favorite'),
    );
    _checkResponse(response);
    return FlutterWidget.fromJson(json.decode(response.body));
  }

  // === Categories ===

  Future<List<Category>> getCategories() async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.categoriesUrl}/'),
    );
    _checkResponse(response);
    final List<dynamic> data = json.decode(response.body);
    return data.map((j) => Category.fromJson(j)).toList();
  }

  Future<Category> createCategory({
    required String name,
    String? description,
    String? icon,
    String? color,
  }) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.categoriesUrl}/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': name,
        if (description != null) 'description': description,
        if (icon != null) 'icon': icon,
        if (color != null) 'color': color,
      }),
    );
    _checkResponse(response);
    return Category.fromJson(json.decode(response.body));
  }

  // === Tags ===

  Future<List<Tag>> getTags() async {
    final response = await _client.get(Uri.parse('${ApiConfig.tagsUrl}/'));
    _checkResponse(response);
    final List<dynamic> data = json.decode(response.body);
    return data.map((j) => Tag.fromJson(j)).toList();
  }

  Future<Tag> createTag({required String name, String? color}) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.tagsUrl}/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': name,
        if (color != null) 'color': color,
      }),
    );
    _checkResponse(response);
    return Tag.fromJson(json.decode(response.body));
  }

  // === Health ===

  Future<bool> checkHealth() async {
    try {
      final response = await _client.get(
        Uri.parse('${ApiConfig.baseUrl}/health'),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void _checkResponse(http.Response response) {
    if (response.statusCode >= 400) {
      throw ApiException(
        statusCode: response.statusCode,
        message: response.body,
      );
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
