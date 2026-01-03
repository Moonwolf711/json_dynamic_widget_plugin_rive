import 'package:flutter/material.dart';

class WFLSfxPanel extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final List<Map<String, dynamic>> sfxButtons;
  final Function(String) onPlaySfx;

  const WFLSfxPanel({
    super.key,
    required this.isExpanded,
    required this.onToggleExpanded,
    required this.sfxButtons,
    required this.onPlaySfx,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 20,
      right: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Header with collapse toggle
          GestureDetector(
            onTap: onToggleExpanded,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.music_note, color: Colors.purple, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'SFX',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white70,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          // Expandable button grid
          if (isExpanded)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: sfxButtons
                        .sublist(0, 4)
                        .map((sfx) => _buildSfxButton(sfx))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: sfxButtons
                        .sublist(4, 8)
                        .map((sfx) => _buildSfxButton(sfx))
                        .toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSfxButton(Map<String, dynamic> sfx) {
    final color = Color(sfx['color'] as int);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: '${sfx['label']} (${sfx['key']})',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onPlaySfx(sfx['name'] as String),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withOpacity(0.8), color.withOpacity(0.5)],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color, width: 1),
                boxShadow: [
                  BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(sfx['icon'] as IconData, color: Colors.white, size: 22),
                  const SizedBox(height: 2),
                  Text(sfx['key'] as String,
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
