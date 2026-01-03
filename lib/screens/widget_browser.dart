import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/api_service.dart';
import '../api/models.dart';

/// Widget Browser - Browse and view Flutter widgets from the API
class WidgetBrowserScreen extends StatefulWidget {
  const WidgetBrowserScreen({super.key});

  @override
  State<WidgetBrowserScreen> createState() => _WidgetBrowserScreenState();
}

class _WidgetBrowserScreenState extends State<WidgetBrowserScreen> {
  final FlutterViewerApi _api = FlutterViewerApi();

  List<FlutterWidget> _widgets = [];
  List<Category> _categories = [];
  List<Tag> _tags = [];

  int? _selectedCategoryId;
  final Set<int> _selectedTagIds = {};
  String _searchQuery = '';

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.getCategories(),
        _api.getTags(),
        _api.getWidgets(
          categoryId: _selectedCategoryId,
          tagIds: _selectedTagIds.isNotEmpty ? _selectedTagIds.toList() : null,
          search: _searchQuery.isNotEmpty ? _searchQuery : null,
        ),
      ]);

      setState(() {
        _categories = results[0] as List<Category>;
        _tags = results[1] as List<Tag>;
        _widgets = results[2] as List<FlutterWidget>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshWidgets() async {
    try {
      final widgets = await _api.getWidgets(
        categoryId: _selectedCategoryId,
        tagIds: _selectedTagIds.isNotEmpty ? _selectedTagIds.toList() : null,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      if (mounted) setState(() => _widgets = widgets);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget Browser'),
        backgroundColor: const Color(0xFF1a1a2e),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Failed to connect to API', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Row(
      children: [
        // Sidebar with filters
        SizedBox(
          width: 250,
          child: _buildSidebar(),
        ),
        const VerticalDivider(width: 1),
        // Main content
        Expanded(
          child: _buildWidgetGrid(),
        ),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: const Color(0xFF16213e),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Search
          TextField(
            decoration: const InputDecoration(
              hintText: 'Search widgets...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              _searchQuery = value;
              _refreshWidgets();
            },
          ),
          const SizedBox(height: 24),

          // Categories
          Text('Categories', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _buildCategoryChip(null, 'All'),
          ..._categories.map((c) => _buildCategoryChip(c.id, c.name)),
          const SizedBox(height: 24),

          // Tags
          Text('Tags', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((t) => _buildTagChip(t)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(int? id, String name) {
    final isSelected = _selectedCategoryId == id;
    return ListTile(
      dense: true,
      selected: isSelected,
      selectedTileColor: Colors.blue.withValues(alpha: 0.2),
      title: Text(name),
      onTap: () {
        setState(() => _selectedCategoryId = id);
        _refreshWidgets();
      },
    );
  }

  Widget _buildTagChip(Tag tag) {
    final isSelected = _selectedTagIds.contains(tag.id);
    return FilterChip(
      label: Text(tag.name),
      selected: isSelected,
      selectedColor: tag.color != null
          ? Color(int.parse(tag.color!.replaceFirst('#', '0xFF')))
          : Colors.blue,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedTagIds.add(tag.id);
          } else {
            _selectedTagIds.remove(tag.id);
          }
        });
        _refreshWidgets();
      },
    );
  }

  Widget _buildWidgetGrid() {
    if (_widgets.isEmpty) {
      return const Center(
        child: Text('No widgets found'),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 350,
        childAspectRatio: 1.0,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _widgets.length,
      itemBuilder: (context, index) => _buildWidgetCard(_widgets[index]),
    );
  }

  Widget _buildWidgetCard(FlutterWidget widget) {
    return Card(
      color: const Color(0xFF1f4068),
      child: InkWell(
        onTap: () => _showWidgetDetail(widget),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    widget.isStateful ? Icons.change_circle : Icons.widgets,
                    color: widget.isStateful ? Colors.orange : Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Category
              if (widget.category != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.category!.name,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              const SizedBox(height: 8),

              // Description
              if (widget.description != null)
                Expanded(
                  child: Text(
                    widget.description!,
                    style: const TextStyle(color: Colors.grey),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const Spacer(),

              // Tags
              if (widget.tags.isNotEmpty)
                Wrap(
                  spacing: 4,
                  children: widget.tags
                      .take(3)
                      .map((t) => Chip(
                            label: Text(t.name, style: const TextStyle(fontSize: 10)),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ))
                      .toList(),
                ),
              const SizedBox(height: 8),

              // Stats
              Row(
                children: [
                  Icon(Icons.visibility, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text('${widget.viewCount}', style: TextStyle(color: Colors.grey[400])),
                  const SizedBox(width: 16),
                  Icon(Icons.favorite, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text('${widget.favoriteCount}', style: TextStyle(color: Colors.grey[400])),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWidgetDetail(FlutterWidget widget) {
    showDialog(
      context: context,
      builder: (context) => WidgetDetailDialog(widget: widget, api: _api),
    );
  }
}

/// Dialog showing widget details and source code
class WidgetDetailDialog extends StatelessWidget {
  final FlutterWidget widget;
  final FlutterViewerApi api;

  const WidgetDetailDialog({
    super.key,
    required this.widget,
    required this.api,
  });

  void _onFavorite(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await api.favoriteWidget(widget.id);
    messenger.showSnackBar(
      const SnackBar(content: Text('Added to favorites!')),
    );
  }

  void _onCopy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.sourceCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  widget.isStateful ? Icons.change_circle : Icons.widgets,
                  size: 32,
                  color: widget.isStateful ? Colors.orange : Colors.blue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (widget.category != null)
                        Text(
                          widget.category!.name,
                          style: const TextStyle(color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.favorite_border),
                  onPressed: () => _onFavorite(context),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy source code',
                  onPressed: () => _onCopy(context),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            if (widget.description != null) ...[
              Text(widget.description!),
              const SizedBox(height: 16),
            ],

            // Tags
            if (widget.tags.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                children: widget.tags
                    .map((t) => Chip(label: Text(t.name)))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Source code
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0d1117),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    widget.sourceCode,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Color(0xFFc9d1d9),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
