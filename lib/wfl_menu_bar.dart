// WFL Menu Bar - Desktop application menu
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Callback types for menu actions
typedef MenuCallback = void Function();
typedef FileCallback = void Function(String path);

/// Menu bar configuration
class WFLMenuBarConfig {
  // File menu callbacks
  final MenuCallback? onNewProject;
  final MenuCallback? onOpenProject;
  final MenuCallback? onSaveProject;
  final MenuCallback? onSaveProjectAs;
  final MenuCallback? onExportVideo;
  final MenuCallback? onExportGif;
  final MenuCallback? onExportFrames;
  final MenuCallback? onImportRive;
  final MenuCallback? onImportAudio;
  final MenuCallback? onExit;

  // Edit menu callbacks
  final MenuCallback? onUndo;
  final MenuCallback? onRedo;
  final MenuCallback? onCut;
  final MenuCallback? onCopy;
  final MenuCallback? onPaste;
  final MenuCallback? onDelete;
  final MenuCallback? onSelectAll;
  final MenuCallback? onDeselectAll;

  // View menu callbacks
  final MenuCallback? onZoomIn;
  final MenuCallback? onZoomOut;
  final MenuCallback? onZoomReset;
  final MenuCallback? onToggleFullscreen;
  final MenuCallback? onToggleTimeline;
  final MenuCallback? onToggleInspector;
  final MenuCallback? onToggleConsole;
  final MenuCallback? onToggleBoneEditor;

  // Playback menu callbacks
  final MenuCallback? onPlay;
  final MenuCallback? onPause;
  final MenuCallback? onStop;
  final MenuCallback? onRewind;
  final MenuCallback? onFastForward;
  final MenuCallback? onLoopToggle;

  // Animation menu callbacks
  final MenuCallback? onAddKeyframe;
  final MenuCallback? onDeleteKeyframe;
  final MenuCallback? onGoToNextKeyframe;
  final MenuCallback? onGoToPrevKeyframe;
  final MenuCallback? onResetPose;
  final MenuCallback? onMirrorPose;

  // Options menu callbacks
  final MenuCallback? onOpenSettings;
  final MenuCallback? onOpenPreferences;
  final MenuCallback? onConfigureHotkeys;
  final MenuCallback? onManagePlugins;

  // Help menu callbacks
  final MenuCallback? onShowAbout;
  final MenuCallback? onShowDocumentation;
  final MenuCallback? onShowKeyboardShortcuts;
  final MenuCallback? onCheckForUpdates;
  final MenuCallback? onReportBug;

  // State getters
  final bool Function()? isPlaying;
  final bool Function()? isLooping;
  final bool Function()? canUndo;
  final bool Function()? canRedo;
  final bool Function()? isFullscreen;
  final bool Function()? isTimelineVisible;
  final bool Function()? isInspectorVisible;
  final bool Function()? isConsoleVisible;
  final bool Function()? isBoneEditorVisible;

  const WFLMenuBarConfig({
    this.onNewProject,
    this.onOpenProject,
    this.onSaveProject,
    this.onSaveProjectAs,
    this.onExportVideo,
    this.onExportGif,
    this.onExportFrames,
    this.onImportRive,
    this.onImportAudio,
    this.onExit,
    this.onUndo,
    this.onRedo,
    this.onCut,
    this.onCopy,
    this.onPaste,
    this.onDelete,
    this.onSelectAll,
    this.onDeselectAll,
    this.onZoomIn,
    this.onZoomOut,
    this.onZoomReset,
    this.onToggleFullscreen,
    this.onToggleTimeline,
    this.onToggleInspector,
    this.onToggleConsole,
    this.onToggleBoneEditor,
    this.onPlay,
    this.onPause,
    this.onStop,
    this.onRewind,
    this.onFastForward,
    this.onLoopToggle,
    this.onAddKeyframe,
    this.onDeleteKeyframe,
    this.onGoToNextKeyframe,
    this.onGoToPrevKeyframe,
    this.onResetPose,
    this.onMirrorPose,
    this.onOpenSettings,
    this.onOpenPreferences,
    this.onConfigureHotkeys,
    this.onManagePlugins,
    this.onShowAbout,
    this.onShowDocumentation,
    this.onShowKeyboardShortcuts,
    this.onCheckForUpdates,
    this.onReportBug,
    this.isPlaying,
    this.isLooping,
    this.canUndo,
    this.canRedo,
    this.isFullscreen,
    this.isTimelineVisible,
    this.isInspectorVisible,
    this.isConsoleVisible,
    this.isBoneEditorVisible,
  });
}

class WFLMenuBar extends StatelessWidget {
  final WFLMenuBarConfig config;

  const WFLMenuBar({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      color: const Color(0xFF2D2D30),
      child: MenuBar(
        style: MenuStyle(
          backgroundColor: WidgetStateProperty.all(const Color(0xFF2D2D30)),
          elevation: WidgetStateProperty.all(0),
          padding: WidgetStateProperty.all(EdgeInsets.zero),
        ),
        children: [
          _buildFileMenu(context),
          _buildEditMenu(context),
          _buildSelectionMenu(context),
          _buildViewMenu(context),
          _buildPlaybackMenu(context),
          _buildAnimationMenu(context),
          _buildOptionsMenu(context),
          _buildHelpMenu(context),
        ],
      ),
    );
  }

  SubmenuButton _buildFileMenu(BuildContext context) {
    return SubmenuButton(
      style: _menuButtonStyle(),
      menuChildren: [
        _menuItem('New Project', Icons.create_new_folder, 'Ctrl+N', config.onNewProject),
        _menuItem('Open Project...', Icons.folder_open, 'Ctrl+O', config.onOpenProject),
        const Divider(height: 1),
        _menuItem('Save', Icons.save, 'Ctrl+S', config.onSaveProject),
        _menuItem('Save As...', Icons.save_as, 'Ctrl+Shift+S', config.onSaveProjectAs),
        const Divider(height: 1),
        SubmenuButton(
          style: _menuButtonStyle(),
          menuChildren: [
            _menuItem('Import Rive File...', Icons.animation, null, config.onImportRive),
            _menuItem('Import Audio...', Icons.audio_file, null, config.onImportAudio),
          ],
          child: const _MenuItemContent(icon: Icons.file_download, label: 'Import'),
        ),
        SubmenuButton(
          style: _menuButtonStyle(),
          menuChildren: [
            _menuItem('Export Video (MP4)', Icons.movie, 'Ctrl+E', config.onExportVideo),
            _menuItem('Export GIF', Icons.gif, null, config.onExportGif),
            _menuItem('Export Frame Sequence', Icons.collections, null, config.onExportFrames),
          ],
          child: const _MenuItemContent(icon: Icons.file_upload, label: 'Export'),
        ),
        const Divider(height: 1),
        _menuItem('Exit', Icons.exit_to_app, 'Alt+F4', config.onExit),
      ],
      child: const _TopMenuLabel('File'),
    );
  }

  SubmenuButton _buildEditMenu(BuildContext context) {
    return SubmenuButton(
      style: _menuButtonStyle(),
      menuChildren: [
        _menuItem('Undo', Icons.undo, 'Ctrl+Z', config.onUndo, enabled: config.canUndo?.call() ?? true),
        _menuItem('Redo', Icons.redo, 'Ctrl+Y', config.onRedo, enabled: config.canRedo?.call() ?? true),
        const Divider(height: 1),
        _menuItem('Cut', Icons.content_cut, 'Ctrl+X', config.onCut),
        _menuItem('Copy', Icons.content_copy, 'Ctrl+C', config.onCopy),
        _menuItem('Paste', Icons.content_paste, 'Ctrl+V', config.onPaste),
        _menuItem('Delete', Icons.delete, 'Del', config.onDelete),
        const Divider(height: 1),
        _menuItem('Select All', Icons.select_all, 'Ctrl+A', config.onSelectAll),
        _menuItem('Deselect All', Icons.deselect, 'Ctrl+D', config.onDeselectAll),
      ],
      child: const _TopMenuLabel('Edit'),
    );
  }

  SubmenuButton _buildSelectionMenu(BuildContext context) {
    return SubmenuButton(
      style: _menuButtonStyle(),
      menuChildren: [
        _menuItem('Select All Keyframes', Icons.select_all, null, null),
        _menuItem('Select Range...', Icons.linear_scale, null, null),
        const Divider(height: 1),
        _menuItem('Invert Selection', Icons.flip, null, null),
        _menuItem('Select Similar', Icons.auto_awesome, null, null),
        const Divider(height: 1),
        SubmenuButton(
          style: _menuButtonStyle(),
          menuChildren: [
            _menuItem('Head', Icons.face, null, null),
            _menuItem('Eyes', Icons.visibility, null, null),
            _menuItem('Mouth', Icons.chat_bubble, null, null),
            _menuItem('Body', Icons.accessibility_new, null, null),
          ],
          child: const _MenuItemContent(icon: Icons.category, label: 'Select by Type'),
        ),
      ],
      child: const _TopMenuLabel('Selection'),
    );
  }

  SubmenuButton _buildViewMenu(BuildContext context) {
    return SubmenuButton(
      style: _menuButtonStyle(),
      menuChildren: [
        _menuItem('Zoom In', Icons.zoom_in, 'Ctrl++', config.onZoomIn),
        _menuItem('Zoom Out', Icons.zoom_out, 'Ctrl+-', config.onZoomOut),
        _menuItem('Reset Zoom', Icons.zoom_out_map, 'Ctrl+0', config.onZoomReset),
        const Divider(height: 1),
        _checkboxItem('Fullscreen', config.isFullscreen?.call() ?? false, 'F11', config.onToggleFullscreen),
        const Divider(height: 1),
        _sectionLabel('Panels'),
        _checkboxItem('Timeline', config.isTimelineVisible?.call() ?? true, 'Ctrl+T', config.onToggleTimeline),
        _checkboxItem('Inspector', config.isInspectorVisible?.call() ?? true, 'Ctrl+I', config.onToggleInspector),
        _checkboxItem('Console', config.isConsoleVisible?.call() ?? false, 'Ctrl+`', config.onToggleConsole),
        _checkboxItem('Bone Editor', config.isBoneEditorVisible?.call() ?? false, 'Shift+B', config.onToggleBoneEditor),
      ],
      child: const _TopMenuLabel('View'),
    );
  }

  SubmenuButton _buildPlaybackMenu(BuildContext context) {
    final isPlaying = config.isPlaying?.call() ?? false;
    return SubmenuButton(
      style: _menuButtonStyle(),
      menuChildren: [
        _menuItem(isPlaying ? 'Pause' : 'Play', isPlaying ? Icons.pause : Icons.play_arrow, 'Space', isPlaying ? config.onPause : config.onPlay),
        _menuItem('Stop', Icons.stop, 'Esc', config.onStop),
        const Divider(height: 1),
        _menuItem('Rewind', Icons.fast_rewind, 'Home', config.onRewind),
        _menuItem('Fast Forward', Icons.fast_forward, 'End', config.onFastForward),
        const Divider(height: 1),
        _checkboxItem('Loop', config.isLooping?.call() ?? true, 'L', config.onLoopToggle),
      ],
      child: const _TopMenuLabel('Playback'),
    );
  }

  SubmenuButton _buildAnimationMenu(BuildContext context) {
    return SubmenuButton(
      style: _menuButtonStyle(),
      menuChildren: [
        _menuItem('Add Keyframe', Icons.add_circle, 'K', config.onAddKeyframe),
        _menuItem('Delete Keyframe', Icons.remove_circle, 'Shift+K', config.onDeleteKeyframe),
        const Divider(height: 1),
        _menuItem('Next Keyframe', Icons.skip_next, '.', config.onGoToNextKeyframe),
        _menuItem('Previous Keyframe', Icons.skip_previous, ',', config.onGoToPrevKeyframe),
        const Divider(height: 1),
        _menuItem('Reset Pose', Icons.refresh, 'R', config.onResetPose),
        _menuItem('Mirror Pose', Icons.flip, 'M', config.onMirrorPose),
        const Divider(height: 1),
        SubmenuButton(
          style: _menuButtonStyle(),
          menuChildren: [
            _menuItem('Mouth Shape 0 (Neutral)', null, '0', null),
            _menuItem('Mouth Shape 1 (A)', null, '1', null),
            _menuItem('Mouth Shape 2 (E)', null, '2', null),
            _menuItem('Mouth Shape 3 (I)', null, '3', null),
            _menuItem('Mouth Shape 4 (O)', null, '4', null),
            _menuItem('Mouth Shape 5 (U)', null, '5', null),
            _menuItem('Mouth Shape 6 (F/V)', null, '6', null),
            _menuItem('Mouth Shape 7 (M/B/P)', null, '7', null),
            _menuItem('Mouth Shape 8 (L/R/W)', null, '8', null),
          ],
          child: const _MenuItemContent(icon: Icons.chat_bubble_outline, label: 'Mouth Shapes'),
        ),
        SubmenuButton(
          style: _menuButtonStyle(),
          menuChildren: [
            _menuItem('Head Left', null, 'Left', null),
            _menuItem('Head Right', null, 'Right', null),
            _menuItem('Head Center', null, 'Up', null),
          ],
          child: const _MenuItemContent(icon: Icons.face, label: 'Head Position'),
        ),
      ],
      child: const _TopMenuLabel('Animation'),
    );
  }

  SubmenuButton _buildOptionsMenu(BuildContext context) {
    return SubmenuButton(
      style: _menuButtonStyle(),
      menuChildren: [
        _menuItem('Settings...', Icons.settings, 'Ctrl+,', config.onOpenSettings),
        _menuItem('Preferences...', Icons.tune, null, config.onOpenPreferences),
        const Divider(height: 1),
        _menuItem('Configure Hotkeys...', Icons.keyboard, null, config.onConfigureHotkeys),
        _menuItem('Manage Plugins...', Icons.extension, null, config.onManagePlugins),
        const Divider(height: 1),
        SubmenuButton(
          style: _menuButtonStyle(),
          menuChildren: [
            _menuItem('Dark (Default)', Icons.dark_mode, null, null),
            _menuItem('Light', Icons.light_mode, null, null),
            _menuItem('System', Icons.brightness_auto, null, null),
          ],
          child: const _MenuItemContent(icon: Icons.palette, label: 'Theme'),
        ),
        SubmenuButton(
          style: _menuButtonStyle(),
          menuChildren: [
            _menuItem('24 FPS (Film)', null, null, null),
            _menuItem('30 FPS (Video)', null, null, null),
            _menuItem('60 FPS (Smooth)', null, null, null),
          ],
          child: const _MenuItemContent(icon: Icons.speed, label: 'Framerate'),
        ),
        SubmenuButton(
          style: _menuButtonStyle(),
          menuChildren: [
            _menuItem('720p (HD)', null, null, null),
            _menuItem('1080p (Full HD)', null, null, null),
            _menuItem('1440p (2K)', null, null, null),
            _menuItem('2160p (4K)', null, null, null),
          ],
          child: const _MenuItemContent(icon: Icons.aspect_ratio, label: 'Resolution'),
        ),
      ],
      child: const _TopMenuLabel('Options'),
    );
  }

  SubmenuButton _buildHelpMenu(BuildContext context) {
    return SubmenuButton(
      style: _menuButtonStyle(),
      menuChildren: [
        _menuItem('Documentation', Icons.menu_book, 'F1', config.onShowDocumentation),
        _menuItem('Keyboard Shortcuts', Icons.keyboard, 'Ctrl+/', config.onShowKeyboardShortcuts),
        const Divider(height: 1),
        _menuItem('Check for Updates...', Icons.system_update, null, config.onCheckForUpdates),
        _menuItem('Report a Bug...', Icons.bug_report, null, config.onReportBug),
        const Divider(height: 1),
        _menuItem('About WFL Animator', Icons.info, null, config.onShowAbout),
      ],
      child: const _TopMenuLabel('Help'),
    );
  }

  ButtonStyle _menuButtonStyle() {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return const Color(0xFF3E3E42);
        }
        return Colors.transparent;
      }),
      foregroundColor: WidgetStateProperty.all(Colors.white70),
      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
      minimumSize: WidgetStateProperty.all(const Size(0, 24)),
    );
  }

  Widget _menuItem(String label, IconData? icon, String? shortcut, MenuCallback? onPressed, {bool enabled = true}) {
    return MenuItemButton(
      onPressed: enabled ? onPressed : null,
      style: _menuButtonStyle(),
      shortcut: shortcut != null ? _parseShortcut(shortcut) : null,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: enabled ? Colors.white70 : Colors.white30),
            const SizedBox(width: 8),
          ] else
            const SizedBox(width: 24),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: enabled ? Colors.white : Colors.white38,
              ),
            ),
          ),
          if (shortcut != null) ...[
            const SizedBox(width: 24),
            Text(
              shortcut,
              style: const TextStyle(fontSize: 11, color: Colors.white38),
            ),
          ],
        ],
      ),
    );
  }

  Widget _checkboxItem(String label, bool checked, String? shortcut, MenuCallback? onPressed) {
    return MenuItemButton(
      onPressed: onPressed,
      style: _menuButtonStyle(),
      shortcut: shortcut != null ? _parseShortcut(shortcut) : null,
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_box : Icons.check_box_outline_blank,
            size: 16,
            color: Colors.white70,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
          ),
          if (shortcut != null) ...[
            const SizedBox(width: 24),
            Text(shortcut, style: const TextStyle(fontSize: 11, color: Colors.white38)),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(fontSize: 10, color: Colors.white38, letterSpacing: 1),
      ),
    );
  }

  SingleActivator? _parseShortcut(String shortcut) {
    final parts = shortcut.split('+');
    LogicalKeyboardKey? key;
    bool ctrl = false, shift = false, alt = false;

    for (final part in parts) {
      switch (part.toLowerCase()) {
        case 'ctrl':
          ctrl = true;
          break;
        case 'shift':
          shift = true;
          break;
        case 'alt':
          alt = true;
          break;
        case 'space':
          key = LogicalKeyboardKey.space;
          break;
        case 'esc':
          key = LogicalKeyboardKey.escape;
          break;
        case 'del':
          key = LogicalKeyboardKey.delete;
          break;
        case 'home':
          key = LogicalKeyboardKey.home;
          break;
        case 'end':
          key = LogicalKeyboardKey.end;
          break;
        case 'left':
          key = LogicalKeyboardKey.arrowLeft;
          break;
        case 'right':
          key = LogicalKeyboardKey.arrowRight;
          break;
        case 'up':
          key = LogicalKeyboardKey.arrowUp;
          break;
        case 'down':
          key = LogicalKeyboardKey.arrowDown;
          break;
        case 'f1':
          key = LogicalKeyboardKey.f1;
          break;
        case 'f11':
          key = LogicalKeyboardKey.f11;
          break;
        default:
          if (part.length == 1) {
            final code = part.toLowerCase().codeUnitAt(0);
            if (code >= 97 && code <= 122) {
              // a-z
              key = LogicalKeyboardKey(code - 32 + 0x00000041 - 0x41 + 65);
            } else if (code >= 48 && code <= 57) {
              // 0-9
              key = LogicalKeyboardKey(code);
            } else if (part == '+') {
              key = LogicalKeyboardKey.add;
            } else if (part == '-') {
              key = LogicalKeyboardKey.minus;
            } else if (part == '/') {
              key = LogicalKeyboardKey.slash;
            } else if (part == '`') {
              key = LogicalKeyboardKey.backquote;
            } else if (part == ',') {
              key = LogicalKeyboardKey.comma;
            } else if (part == '.') {
              key = LogicalKeyboardKey.period;
            }
          }
      }
    }

    if (key != null) {
      return SingleActivator(key, control: ctrl, shift: shift, alt: alt);
    }
    return null;
  }
}

class _TopMenuLabel extends StatelessWidget {
  final String label;
  const _TopMenuLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.white70),
      ),
    );
  }
}

class _MenuItemContent extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuItemContent({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.white)),
      ],
    );
  }
}
