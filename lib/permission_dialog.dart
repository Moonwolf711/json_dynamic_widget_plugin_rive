// WFL Permission Dialog
// Shows confirmation with "Apply for all" and dangerous skip options

import 'package:flutter/material.dart';

class PermissionDialog extends StatefulWidget {
  final String title;
  final String message;
  final String? codePreview;
  final VoidCallback onApply;
  final VoidCallback onCancel;
  final Function(bool applyForAll, bool skipPermissions)? onApplyWithOptions;

  const PermissionDialog({
    super.key,
    required this.title,
    required this.message,
    this.codePreview,
    required this.onApply,
    required this.onCancel,
    this.onApplyWithOptions,
  });

  /// Show the dialog and return result
  static Future<PermissionResult?> show(
    BuildContext context, {
    required String title,
    required String message,
    String? codePreview,
  }) async {
    return showDialog<PermissionResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PermissionDialog(
        title: title,
        message: message,
        codePreview: codePreview,
        onApply: () => Navigator.pop(ctx, PermissionResult(approved: true)),
        onCancel: () => Navigator.pop(ctx, PermissionResult(approved: false)),
        onApplyWithOptions: (applyForAll, skip) => Navigator.pop(
          ctx,
          PermissionResult(
            approved: true,
            applyForAll: applyForAll,
            skipPermissions: skip,
          ),
        ),
      ),
    );
  }

  @override
  State<PermissionDialog> createState() => _PermissionDialogState();
}

class _PermissionDialogState extends State<PermissionDialog> {
  bool _applyForAll = false;
  bool _showDangerousOptions = false;
  bool _skipPermissions = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2A2A2A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.blue.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 20),

            // Message
            Text(
              widget.message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),

            // Code preview (if provided)
            if (widget.codePreview != null) ...[
              const SizedBox(height: 16),
              _buildCodePreview(),
            ],

            const SizedBox(height: 24),

            // Apply for all checkbox
            _buildApplyForAllOption(),

            const SizedBox(height: 12),

            // Dangerous options toggle
            _buildDangerousOptionsToggle(),

            // Dangerous options (hidden by default)
            if (_showDangerousOptions) ...[
              const SizedBox(height: 12),
              _buildSkipPermissionsOption(),
            ],

            const SizedBox(height: 24),

            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.security,
            color: Colors.blue,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white60),
          onPressed: widget.onCancel,
          splashRadius: 20,
          tooltip: 'Cancel',
        ),
      ],
    );
  }

  Widget _buildCodePreview() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF404040)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          widget.codePreview!,
          style: const TextStyle(
            fontFamily: 'Consolas, Monaco, monospace',
            fontSize: 12,
            color: Color(0xFFD4D4D4),
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildApplyForAllOption() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _applyForAll
              ? Colors.blue.withValues(alpha: 0.5)
              : const Color(0xFF404040),
        ),
      ),
      child: CheckboxListTile(
        value: _applyForAll,
        onChanged: (value) => setState(() => _applyForAll = value ?? false),
        title: const Text(
          'Apply for all similar changes',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        subtitle: Text(
          'Skip this dialog for remaining items in this session',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        activeColor: Colors.blue,
        checkColor: Colors.white,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  Widget _buildDangerousOptionsToggle() {
    return GestureDetector(
      onTap: () => setState(() => _showDangerousOptions = !_showDangerousOptions),
      child: Row(
        children: [
          Icon(
            _showDangerousOptions
                ? Icons.keyboard_arrow_down
                : Icons.keyboard_arrow_right,
            color: Colors.orange.withValues(alpha: 0.7),
            size: 20,
          ),
          const SizedBox(width: 4),
          Text(
            'Advanced options',
            style: TextStyle(
              color: Colors.orange.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkipPermissionsOption() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _skipPermissions
              ? Colors.red.withValues(alpha: 0.5)
              : Colors.red.withValues(alpha: 0.2),
        ),
      ),
      child: CheckboxListTile(
        value: _skipPermissions,
        onChanged: (value) => setState(() => _skipPermissions = value ?? false),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange, size: 18),
            SizedBox(width: 8),
            Text(
              'Dangerously skip all permissions',
              style: TextStyle(color: Colors.orange, fontSize: 14),
            ),
          ],
        ),
        subtitle: Text(
          'Auto-apply all changes without confirmation. Use with caution!',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
          ),
        ),
        activeColor: Colors.orange,
        checkColor: Colors.white,
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Cancel button
        TextButton(
          onPressed: widget.onCancel,
          style: TextButton.styleFrom(
            foregroundColor: Colors.white70,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 12),

        // Apply button
        ElevatedButton(
          onPressed: () {
            if (widget.onApplyWithOptions != null) {
              widget.onApplyWithOptions!(_applyForAll, _skipPermissions);
            } else {
              widget.onApply();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check, size: 18),
              const SizedBox(width: 8),
              Text(_applyForAll ? 'Apply All' : 'Apply'),
            ],
          ),
        ),
      ],
    );
  }
}

/// Result from permission dialog
class PermissionResult {
  final bool approved;
  final bool applyForAll;
  final bool skipPermissions;

  PermissionResult({
    required this.approved,
    this.applyForAll = false,
    this.skipPermissions = false,
  });
}
