/// WFL Desktop Taskbar Navigation System
/// Professional taskbar with routes, backend integration, and notification dots
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ==================== APP DEFINITION ====================

/// A taskbar app with routing and backend support
class WFLTaskApp {
  final String id;
  final IconData icon;
  final String label;
  final String route;
  final String? apiPath;
  final Color? accentColor;

  const WFLTaskApp({
    required this.id,
    required this.icon,
    required this.label,
    required this.route,
    this.apiPath,
    this.accentColor,
  });
}

/// Default WFL apps
const wflApps = [
  WFLTaskApp(
    id: 'viewer',
    icon: Icons.tv,
    label: 'Viewer',
    route: '/viewer',
    apiPath: '/viewer',
    accentColor: Colors.cyan,
  ),
  WFLTaskApp(
    id: 'assets',
    icon: Icons.folder_special,
    label: 'Assets',
    route: '/assets',
    apiPath: '/assets',
    accentColor: Colors.orange,
  ),
  WFLTaskApp(
    id: 'ai',
    icon: Icons.psychology,
    label: 'AI Roast',
    route: '/ai',
    apiPath: '/ai',
    accentColor: Colors.purple,
  ),
  WFLTaskApp(
    id: 'audio',
    icon: Icons.music_note,
    label: 'Audio',
    route: '/audio',
    apiPath: '/audio',
    accentColor: Colors.green,
  ),
  WFLTaskApp(
    id: 'export',
    icon: Icons.movie_creation,
    label: 'Export',
    route: '/export',
    apiPath: '/export',
    accentColor: Colors.red,
  ),
];

// ==================== BACKEND SERVICE ====================

/// Backend service for app session management
class WFLBackend {
  final String baseUrl;

  WFLBackend(this.baseUrl);

  /// Notify backend when an app is opened
  Future<Map<String, dynamic>?> openAppSession(String appId) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/apps/open'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(
            {'appId': appId, 'timestamp': DateTime.now().toIso8601String()}),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Backend openAppSession error: $e');
    }
    return null;
  }

  /// Get notification status for apps
  Future<Map<String, bool>> getNotifications() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/notifications'));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return data.map((k, v) => MapEntry(k, v as bool));
      }
    } catch (e) {
      debugPrint('Backend getNotifications error: $e');
    }
    return {};
  }
}

// ==================== TASKBAR WIDGET ====================

/// Desktop-style taskbar with animated buttons
class WFLTaskbar extends StatelessWidget {
  final List<WFLTaskApp> apps;
  final int activeIndex;
  final ValueChanged<int> onSelect;
  final bool Function(String appId)? showDotForAppId;
  final bool isVertical;
  final double height;

  const WFLTaskbar({
    super.key,
    required this.apps,
    required this.activeIndex,
    required this.onSelect,
    this.showDotForAppId,
    this.isVertical = false,
    this.height = 64,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];

    for (int i = 0; i < apps.length; i++) {
      buttons.add(
        WFLTaskButton(
          icon: apps[i].icon,
          label: apps[i].label,
          isActive: i == activeIndex,
          showDot: showDotForAppId?.call(apps[i].id) ?? false,
          accentColor: apps[i].accentColor ?? Colors.blue,
          onTap: () => onSelect(i),
        ),
      );
      if (i < apps.length - 1) {
        buttons.add(
            SizedBox(width: isVertical ? 0 : 8, height: isVertical ? 8 : 0));
      }
    }

    return Material(
      elevation: 10,
      color: const Color(0xFF1A1A2E),
      child: SafeArea(
        top: false,
        child: Container(
          height: isVertical ? null : height,
          width: isVertical ? height : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: isVertical
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: buttons)
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: buttons),
        ),
      ),
    );
  }
}

// ==================== TASK BUTTON ====================

/// Individual taskbar button with animation and notification dot
class WFLTaskButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool showDot;
  final Color accentColor;
  final VoidCallback onTap;

  const WFLTaskButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.showDot,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<WFLTaskButton> createState() => _WFLTaskButtonState();
}

class _WFLTaskButtonState extends State<WFLTaskButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isHighlighted = widget.isActive || _hovered;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: widget.isActive
                ? widget.accentColor.withAlpha(40)
                : _hovered
                    ? Colors.white.withAlpha(15)
                    : Colors.transparent,
            border: Border.all(
              color: widget.isActive
                  ? widget.accentColor
                  : _hovered
                      ? Colors.white.withAlpha(50)
                      : Colors.transparent,
              width: widget.isActive ? 2 : 1,
            ),
            boxShadow: widget.isActive
                ? [
                    BoxShadow(
                      color: widget.accentColor.withAlpha(60),
                      blurRadius: 8,
                      spreadRadius: 0,
                    )
                  ]
                : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.icon,
                    size: 22,
                    color:
                        widget.isActive ? widget.accentColor : Colors.white70,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color:
                          widget.isActive ? widget.accentColor : Colors.white70,
                      fontWeight:
                          widget.isActive ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              // Notification dot
              if (widget.showDot)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                      border:
                          Border.all(color: const Color(0xFF1A1A2E), width: 2),
                    ),
                  ),
                ),
              // Active indicator bar
              if (widget.isActive)
                Positioned(
                  bottom: -10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 20,
                      height: 3,
                      decoration: BoxDecoration(
                        color: widget.accentColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== SHELL WITH TASKBAR ====================

/// Main shell that provides taskbar + content area
class WFLShellWithTaskbar extends StatefulWidget {
  final List<WFLTaskApp> apps;
  final int initialIndex;
  final Widget Function(BuildContext, WFLTaskApp) contentBuilder;
  final WFLBackend? backend;

  const WFLShellWithTaskbar({
    super.key,
    this.apps = wflApps,
    this.initialIndex = 0,
    required this.contentBuilder,
    this.backend,
  });

  @override
  State<WFLShellWithTaskbar> createState() => WFLShellWithTaskbarState();
}

class WFLShellWithTaskbarState extends State<WFLShellWithTaskbar> {
  late int activeIndex;
  Map<String, bool> _notifications = {};

  @override
  void initState() {
    super.initState();
    activeIndex = widget.initialIndex;
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (widget.backend != null) {
      final notifs = await widget.backend!.getNotifications();
      if (mounted) {
        setState(() => _notifications = notifs);
      }
    }
  }

  Future<void> selectApp(int index) async {
    if (index == activeIndex) return;

    final app = widget.apps[index];
    setState(() => activeIndex = index);

    // Notify backend
    if (widget.backend != null) {
      await widget.backend!.openAppSession(app.id);
    }

    // Clear notification for this app
    if (_notifications[app.id] == true) {
      setState(() => _notifications[app.id] = false);
    }
  }

  void setNotification(String appId, bool hasNotification) {
    setState(() => _notifications[appId] = hasNotification);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: widget.contentBuilder(context, widget.apps[activeIndex]),
      bottomNavigationBar: WFLTaskbar(
        apps: widget.apps,
        activeIndex: activeIndex,
        onSelect: selectApp,
        showDotForAppId: (id) => _notifications[id] ?? false,
      ),
    );
  }
}

// ==================== COMPACT ICON-ONLY TASKBAR ====================

/// Compact taskbar with just icons (for space-constrained layouts)
class WFLCompactTaskbar extends StatelessWidget {
  final List<WFLTaskApp> apps;
  final int activeIndex;
  final ValueChanged<int> onSelect;
  final bool Function(String appId)? showDotForAppId;

  const WFLCompactTaskbar({
    super.key,
    required this.apps,
    required this.activeIndex,
    required this.onSelect,
    this.showDotForAppId,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 10,
      color: const Color(0xFF1A1A2E),
      child: SafeArea(
        top: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int i = 0; i < apps.length; i++)
                _CompactButton(
                  icon: apps[i].icon,
                  isActive: i == activeIndex,
                  showDot: showDotForAppId?.call(apps[i].id) ?? false,
                  accentColor: apps[i].accentColor ?? Colors.blue,
                  onTap: () => onSelect(i),
                  tooltip: apps[i].label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final bool showDot;
  final Color accentColor;
  final VoidCallback onTap;
  final String tooltip;

  const _CompactButton({
    required this.icon,
    required this.isActive,
    required this.showDot,
    required this.accentColor,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    isActive ? accentColor.withAlpha(40) : Colors.transparent,
                border: Border.all(
                  color: isActive ? accentColor : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Icon(
                icon,
                size: 24,
                color: isActive ? accentColor : Colors.white60,
              ),
            ),
            if (showDot)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                    border:
                        Border.all(color: const Color(0xFF1A1A2E), width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
