/// WFL Action Dispatcher System
/// Data-driven button definitions with unified dispatch
/// Supports: routes, toggles, HTTP, WebSocket, callbacks, state machines
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ==================== ACTION TYPES ====================

enum ActionType {
  route, // Navigate to a screen
  toggle, // Toggle a boolean state (mute, mic, REC)
  http, // HTTP POST to backend
  ws, // WebSocket event
  callback, // Custom function
  stateMachine, // Trigger animation/dialogue state
  sfx, // Play sound effect
  sequence, // Run multiple actions in order
}

// ==================== ACTION DEFINITION ====================

class ActionDef {
  final ActionType type;
  final String? value;
  final Future<void> Function()? fn;
  final List<ActionDef>? sequence;
  final Map<String, dynamic>? payload;

  const ActionDef._({
    required this.type,
    this.value,
    this.fn,
    this.sequence,
    this.payload,
  });

  /// Navigate to a named route
  const ActionDef.route(String route)
      : this._(type: ActionType.route, value: route);

  /// Toggle a boolean state (mute, rec, mic, etc.)
  const ActionDef.toggle(String key)
      : this._(type: ActionType.toggle, value: key);

  /// HTTP POST to endpoint
  const ActionDef.http(String endpoint, {Map<String, dynamic>? payload})
      : this._(type: ActionType.http, value: endpoint, payload: payload);

  /// WebSocket event
  const ActionDef.ws(String eventName, {Map<String, dynamic>? payload})
      : this._(type: ActionType.ws, value: eventName, payload: payload);

  /// Custom callback function
  ActionDef.callback(Future<void> Function() callback)
      : this._(type: ActionType.callback, fn: callback);

  /// Trigger state machine transition
  const ActionDef.stateMachine(String stateName)
      : this._(type: ActionType.stateMachine, value: stateName);

  /// Play sound effect
  const ActionDef.sfx(String sfxName)
      : this._(type: ActionType.sfx, value: sfxName);

  /// Run multiple actions in sequence
  const ActionDef.sequence(List<ActionDef> actions)
      : this._(type: ActionType.sequence, sequence: actions);
}

// ==================== BUTTON DEFINITION ====================

class TaskButtonDef {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final ActionDef action;
  final String? badge; // Optional badge text (queue count, etc.)
  final String? toggleKey; // If this button reflects a toggle state
  final String? hotkey; // Keyboard shortcut label

  const TaskButtonDef({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.action,
    this.badge,
    this.toggleKey,
    this.hotkey,
  });
}

// ==================== STATE NOTIFIER ====================

/// Reactive state for buttons (toggles, badges, active states)
class ButtonState extends ChangeNotifier {
  final Map<String, bool> _toggles = {};
  final Map<String, String> _badges = {};
  final Map<String, bool> _loading = {};
  String? _activeButtonId;

  // Toggles
  bool getToggle(String key) => _toggles[key] ?? false;
  void setToggle(String key, bool value) {
    _toggles[key] = value;
    notifyListeners();
  }

  void toggle(String key) {
    _toggles[key] = !(_toggles[key] ?? false);
    notifyListeners();
  }

  // Badges (queue count, notification count, etc.)
  String? getBadge(String buttonId) => _badges[buttonId];
  void setBadge(String buttonId, String? value) {
    if (value == null) {
      _badges.remove(buttonId);
    } else {
      _badges[buttonId] = value;
    }
    notifyListeners();
  }

  // Loading states
  bool isLoading(String buttonId) => _loading[buttonId] ?? false;
  void setLoading(String buttonId, bool loading) {
    _loading[buttonId] = loading;
    notifyListeners();
  }

  // Active button (for exclusive selections)
  String? get activeButtonId => _activeButtonId;
  void setActiveButton(String? id) {
    _activeButtonId = id;
    notifyListeners();
  }

  // Bulk update from backend
  void updateFromJson(Map<String, dynamic> json) {
    if (json['toggles'] is Map) {
      for (final e in (json['toggles'] as Map).entries) {
        _toggles[e.key as String] = e.value as bool;
      }
    }
    if (json['badges'] is Map) {
      for (final e in (json['badges'] as Map).entries) {
        _badges[e.key as String] = e.value.toString();
      }
    }
    notifyListeners();
  }
}

// ==================== ACTION DISPATCHER ====================

/// Central dispatcher for all button actions
class WFLActionDispatcher {
  final String baseUrl;
  final ButtonState state;
  final void Function(String)? onSfxPlay;
  final void Function(String)? onStateMachineTransition;
  final void Function(String, Map<String, dynamic>)? onWsEmit;

  WFLActionDispatcher({
    required this.baseUrl,
    required this.state,
    this.onSfxPlay,
    this.onStateMachineTransition,
    this.onWsEmit,
  });

  /// Dispatch an action for a button
  Future<void> dispatch(BuildContext context, TaskButtonDef btn) async {
    state.setLoading(btn.id, true);

    try {
      await _executeAction(context, btn.id, btn.action);
    } catch (e) {
      debugPrint('WFLActionDispatcher error for ${btn.id}: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      state.setLoading(btn.id, false);
    }
  }

  Future<void> _executeAction(
      BuildContext context, String buttonId, ActionDef action) async {
    switch (action.type) {
      case ActionType.route:
        if (context.mounted) {
          Navigator.of(context).pushNamed(action.value!);
        }
        break;

      case ActionType.toggle:
        final key = action.value!;
        state.toggle(key);
        // Notify backend
        try {
          await http.post(
            Uri.parse('$baseUrl/toggles/$key'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'enabled': state.getToggle(key)}),
          );
        } catch (e) {
          debugPrint('Toggle sync failed: $e');
        }
        break;

      case ActionType.http:
        await http.post(
          Uri.parse('$baseUrl${action.value}'),
          headers: {'Content-Type': 'application/json'},
          body: action.payload != null ? jsonEncode(action.payload) : null,
        );
        break;

      case ActionType.ws:
        onWsEmit?.call(action.value!, {
          'buttonId': buttonId,
          ...?action.payload,
        });
        break;

      case ActionType.callback:
        await action.fn?.call();
        break;

      case ActionType.stateMachine:
        onStateMachineTransition?.call(action.value!);
        break;

      case ActionType.sfx:
        onSfxPlay?.call(action.value!);
        break;

      case ActionType.sequence:
        if (action.sequence != null) {
          for (final subAction in action.sequence!) {
            await _executeAction(context, buttonId, subAction);
          }
        }
        break;
    }
  }
}

// ==================== BUTTON GRID WIDGET ====================

/// Grid of action buttons
class ActionButtonGrid extends StatelessWidget {
  final List<TaskButtonDef> buttons;
  final WFLActionDispatcher dispatcher;
  final int crossAxisCount;
  final double spacing;
  final double childAspectRatio;

  const ActionButtonGrid({
    super.key,
    required this.buttons,
    required this.dispatcher,
    this.crossAxisCount = 4,
    this.spacing = 10,
    this.childAspectRatio = 1.2,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: dispatcher.state,
      builder: (context, _) {
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: buttons.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, i) {
            final btn = buttons[i];
            return ActionButton(
              def: btn,
              dispatcher: dispatcher,
            );
          },
        );
      },
    );
  }
}

// ==================== SINGLE ACTION BUTTON ====================

class ActionButton extends StatelessWidget {
  final TaskButtonDef def;
  final WFLActionDispatcher dispatcher;

  const ActionButton({
    super.key,
    required this.def,
    required this.dispatcher,
  });

  @override
  Widget build(BuildContext context) {
    final state = dispatcher.state;
    final isToggled = def.toggleKey != null && state.getToggle(def.toggleKey!);
    final isLoading = state.isLoading(def.id);
    final badge = state.getBadge(def.id) ?? def.badge;
    final isActive = state.activeButtonId == def.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isLoading ? null : () => dispatcher.dispatch(context, def),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isToggled || isActive
                  ? [def.color, def.color.withAlpha(180)]
                  : [def.color.withAlpha(200), def.color.withAlpha(120)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isToggled || isActive ? Colors.white : Colors.transparent,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: def.color.withAlpha(isToggled ? 100 : 60),
                blurRadius: isToggled ? 15 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: Stack(
            children: [
              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLoading)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      Icon(def.icon, size: 26, color: Colors.white),
                    const SizedBox(height: 6),
                    Text(
                      def.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Hotkey label
              if (def.hotkey != null)
                Positioned(
                  top: 2,
                  right: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      def.hotkey!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Badge
              if (badge != null)
                Positioned(
                  top: 0,
                  left: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Toggle indicator
              if (isToggled)
                Positioned(
                  bottom: 4,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.greenAccent,
                        boxShadow: [
                          BoxShadow(color: Colors.greenAccent, blurRadius: 6),
                        ],
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

// ==================== WFL BUTTON DEFINITIONS ====================

/// Pre-defined WFL buttons
class WFLButtons {
  // SFX Panel buttons
  static const sfxButtons = [
    TaskButtonDef(
      id: 'sfx_rimshot',
      label: 'Rimshot',
      icon: Icons.music_note,
      color: Color(0xFFE84C64),
      action: ActionDef.sfx('rimshot'),
      hotkey: '1',
    ),
    TaskButtonDef(
      id: 'sfx_laugh',
      label: 'Laugh',
      icon: Icons.emoji_emotions,
      color: Color(0xFF21B6A8),
      action: ActionDef.sfx('laugh'),
      hotkey: '2',
    ),
    TaskButtonDef(
      id: 'sfx_aww',
      label: 'Aww',
      icon: Icons.favorite,
      color: Color(0xFFFF6B9D),
      action: ActionDef.sfx('aww'),
      hotkey: '3',
    ),
    TaskButtonDef(
      id: 'sfx_drumroll',
      label: 'Drumroll',
      icon: Icons.album,
      color: Color(0xFFE0B83C),
      action: ActionDef.sfx('drumroll'),
      hotkey: '4',
    ),
    TaskButtonDef(
      id: 'sfx_airhorn',
      label: 'Air Horn',
      icon: Icons.volume_up,
      color: Color(0xFF6C63FF),
      action: ActionDef.sfx('airhorn'),
      hotkey: '5',
    ),
    TaskButtonDef(
      id: 'sfx_womp',
      label: 'Womp',
      icon: Icons.sentiment_dissatisfied,
      color: Color(0xFF5D4E8C),
      action: ActionDef.sfx('womp'),
      hotkey: '6',
    ),
    TaskButtonDef(
      id: 'sfx_ding',
      label: 'Ding',
      icon: Icons.notifications,
      color: Color(0xFF4CAF50),
      action: ActionDef.sfx('ding'),
      hotkey: '7',
    ),
    TaskButtonDef(
      id: 'sfx_buzzer',
      label: 'Buzzer',
      icon: Icons.cancel,
      color: Color(0xFFFF5722),
      action: ActionDef.sfx('buzzer'),
      hotkey: '8',
    ),
  ];

  // Control panel buttons
  static const controlButtons = [
    TaskButtonDef(
      id: 'rec',
      label: 'REC',
      icon: Icons.fiber_manual_record,
      color: Color(0xFFE53935),
      action: ActionDef.toggle('recording'),
      toggleKey: 'recording',
      hotkey: 'R',
    ),
    TaskButtonDef(
      id: 'mic',
      label: 'MIC',
      icon: Icons.mic,
      color: Color(0xFF2196F3),
      action: ActionDef.toggle('liveMic'),
      toggleKey: 'liveMic',
      hotkey: 'M',
    ),
    TaskButtonDef(
      id: 'mute',
      label: 'Mute',
      icon: Icons.volume_off,
      color: Color(0xFF607D8B),
      action: ActionDef.toggle('muted'),
      toggleKey: 'muted',
    ),
    TaskButtonDef(
      id: 'showMode',
      label: 'Show',
      icon: Icons.play_arrow,
      color: Color(0xFF9C27B0),
      action: ActionDef.toggle('showMode'),
      toggleKey: 'showMode',
      hotkey: 'S',
    ),
  ];

  // Character state buttons
  static const characterButtons = [
    TaskButtonDef(
      id: 'idle',
      label: 'Idle',
      icon: Icons.person,
      color: Color(0xFF78909C),
      action: ActionDef.stateMachine('idle'),
    ),
    TaskButtonDef(
      id: 'talk',
      label: 'Talk',
      icon: Icons.record_voice_over,
      color: Color(0xFF26A69A),
      action: ActionDef.stateMachine('talking'),
    ),
    TaskButtonDef(
      id: 'laugh',
      label: 'Laugh',
      icon: Icons.mood,
      color: Color(0xFFFFB74D),
      action: ActionDef.stateMachine('laughing'),
    ),
    TaskButtonDef(
      id: 'surprised',
      label: 'Surprise',
      icon: Icons.sentiment_very_satisfied,
      color: Color(0xFFFF7043),
      action: ActionDef.stateMachine('surprised'),
    ),
  ];
}
