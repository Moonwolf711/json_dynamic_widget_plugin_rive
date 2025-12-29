import 'package:flutter/material.dart';

class IconLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final double? iconSize;
  final TextStyle? textStyle;
  final double spacing;

  const IconLabel({
    super.key,
    required this.icon,
    required this.text,
    this.iconSize,
    this.textStyle,
    this.spacing = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: iconSize,
        ),
        SizedBox(width: spacing),
        Text(
          text,
          style: textStyle,
        ),
      ],
    );
  }
}