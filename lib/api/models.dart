/// Data models for Flutter Viewer API
library;

class Project {
  final int id;
  final String name;
  final String? description;
  final String path;
  final String? flutterVersion;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Project({
    required this.id,
    required this.name,
    this.description,
    required this.path,
    this.flutterVersion,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      path: json['path'],
      flutterVersion: json['flutter_version'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class Category {
  final int id;
  final String name;
  final String? description;
  final String? icon;
  final String? color;
  final int? parentId;
  final int sortOrder;

  Category({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.color,
    this.parentId,
    required this.sortOrder,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      icon: json['icon'],
      color: json['color'],
      parentId: json['parent_id'],
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}

class Tag {
  final int id;
  final String name;
  final String? color;

  Tag({
    required this.id,
    required this.name,
    this.color,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'],
      name: json['name'],
      color: json['color'],
    );
  }
}

class WidgetPreview {
  final int id;
  final int widgetId;
  final String name;
  final String imagePath;
  final int? width;
  final int? height;
  final String? deviceFrame;
  final bool isPrimary;

  WidgetPreview({
    required this.id,
    required this.widgetId,
    required this.name,
    required this.imagePath,
    this.width,
    this.height,
    this.deviceFrame,
    required this.isPrimary,
  });

  factory WidgetPreview.fromJson(Map<String, dynamic> json) {
    return WidgetPreview(
      id: json['id'],
      widgetId: json['widget_id'],
      name: json['name'],
      imagePath: json['image_path'],
      width: json['width'],
      height: json['height'],
      deviceFrame: json['device_frame'],
      isPrimary: json['is_primary'] ?? false,
    );
  }
}

class FlutterWidget {
  final int id;
  final String name;
  final String? description;
  final String sourceCode;
  final String? filePath;
  final int projectId;
  final int? categoryId;
  final bool isStateful;
  final bool isPublic;
  final List<String>? dependencies;
  final Map<String, dynamic>? props;
  final int viewCount;
  final int favoriteCount;
  final List<Tag> tags;
  final Category? category;
  final List<WidgetPreview> previews;
  final DateTime createdAt;
  final DateTime updatedAt;

  FlutterWidget({
    required this.id,
    required this.name,
    this.description,
    required this.sourceCode,
    this.filePath,
    required this.projectId,
    this.categoryId,
    required this.isStateful,
    required this.isPublic,
    this.dependencies,
    this.props,
    required this.viewCount,
    required this.favoriteCount,
    required this.tags,
    this.category,
    required this.previews,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FlutterWidget.fromJson(Map<String, dynamic> json) {
    return FlutterWidget(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      sourceCode: json['source_code'],
      filePath: json['file_path'],
      projectId: json['project_id'],
      categoryId: json['category_id'],
      isStateful: json['is_stateful'] ?? false,
      isPublic: json['is_public'] ?? true,
      dependencies: json['dependencies'] != null
          ? List<String>.from(json['dependencies'])
          : null,
      props: json['props'],
      viewCount: json['view_count'] ?? 0,
      favoriteCount: json['favorite_count'] ?? 0,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((t) => Tag.fromJson(t))
              .toList() ??
          [],
      category: json['category'] != null
          ? Category.fromJson(json['category'])
          : null,
      previews: (json['previews'] as List<dynamic>?)
              ?.map((p) => WidgetPreview.fromJson(p))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
