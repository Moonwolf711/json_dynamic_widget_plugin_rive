class RoundedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final double borderRadius;
  
  const RoundedCard({
    Key? key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.borderRadius = 12.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFF2D2D30),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            offset: const Offset(0, 2),
            blurRadius: 8.0,
            spreadRadius: 0,
          ),
          // Optional: Add subtle inner shadow for depth
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, 1),
            blurRadius: 3.0,
            spreadRadius: -1,
          ),
        ],
      ),
      child: child,
    );
  }
}

// Shadow properties constants for reuse
class CardShadows {
  static const List<BoxShadow> defaultShadow = [
    BoxShadow(
      color: Color(0x33000000), // 20% opacity black
      offset: Offset(0, 2),
      blurRadius: 8.0,
      spreadRadius: 0,
    ),
  ];
  
  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Color(0x40000000), // 25% opacity black
      offset: Offset(0, 4),
      blurRadius: 12.0,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x1A000000), // 10% opacity black
      offset: Offset(0, 2),
      blurRadius: 4.0,
      spreadRadius: -1,
    ),
  ];
  
  static const List<BoxShadow> subtleShadow = [
    BoxShadow(
      color: Color(0x1A000000), // 10% opacity black
      offset: Offset(0, 1),
      blurRadius: 4.0,
      spreadRadius: 0,
    ),
  ];
}

// Padding presets
class CardPadding {
  static const EdgeInsets none = EdgeInsets.zero;
  static const EdgeInsets small = EdgeInsets.all(8.0);
  static const EdgeInsets medium = EdgeInsets.all(16.0);
  static const EdgeInsets large = EdgeInsets.all(24.0);
  static const EdgeInsets xlarge = EdgeInsets.all(32.0);
  
  // Asymmetric padding options
  static const EdgeInsets horizontalMedium = EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
  static const EdgeInsets horizontalLarge = EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0);
  static const EdgeInsets contentPadding = EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 16.0);
}