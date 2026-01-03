import 'package:flutter/material.dart';

class WFLSubtitleBar extends StatelessWidget {
  final bool visible;
  final String speaker;
  final String text;

  const WFLSubtitleBar({
    super.key,
    required this.visible,
    required this.speaker,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    // Speaker colors: Terry = cyan/blue, Nigel = green, Narrator = white
    Color speakerColor;
    String displayName;

    switch (speaker.toLowerCase()) {
      case 'terry':
        speakerColor = Colors.cyan;
        displayName = 'TERRY';
        break;
      case 'nigel':
        speakerColor = Colors.lightGreen;
        displayName = 'NIGEL';
        break;
      default:
        speakerColor = Colors.white70;
        displayName = speaker.toUpperCase();
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 40,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: speakerColor.withOpacity(0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: speakerColor.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Speaker name
                if (displayName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      displayName,
                      style: TextStyle(
                        color: speakerColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                // Dialogue text with formatting support
                _buildFormattedText(text),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Parse and build formatted text with *italics* and **bold** support
  Widget _buildFormattedText(String text) {
    if (text.isEmpty) return const SizedBox.shrink();

    final List<InlineSpan> spans = [];
    final RegExp pattern = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|([^*]+)');

    for (final match in pattern.allMatches(text)) {
      if (match.group(1) != null) {
        // **bold**
        spans.add(TextSpan(
          text: match.group(1),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ));
      } else if (match.group(2) != null) {
        // *italic*
        spans.add(TextSpan(
          text: match.group(2),
          style: const TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.white,
          ),
        ));
      } else if (match.group(3) != null) {
        // regular text
        spans.add(TextSpan(
          text: match.group(3),
          style: const TextStyle(color: Colors.white),
        ));
      }
    }

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          fontSize: 18,
          height: 1.4,
          fontFamily: 'sans-serif',
        ),
        children: spans,
      ),
    );
  }
}
