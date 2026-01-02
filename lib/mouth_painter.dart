import 'package:flutter/material.dart';

/// SVG-style mouth viseme paths for lip-sync animation
/// Each viseme has outer mouth path, inner mouth path, teeth/tongue opacity
class VisemeData {
  final Path mouthPath;
  final Path innerPath;
  final double teethOpacity;
  final double tongueOpacity;

  const VisemeData({
    required this.mouthPath,
    required this.innerPath,
    this.teethOpacity = 0,
    this.tongueOpacity = 0,
  });
}

/// Parses SVG path "d" attribute into Flutter Path
Path parseSvgPath(String d) {
  final path = Path();
  final commands = RegExp(r'([MmLlQqCcZz])\s*([^MmLlQqCcZz]*)').allMatches(d);

  double x = 0, y = 0;

  for (final match in commands) {
    final cmd = match.group(1)!;
    final params = match.group(2)?.trim() ?? '';
    final nums = RegExp(r'-?\d+\.?\d*').allMatches(params).map((m) => double.parse(m.group(0)!)).toList();

    switch (cmd) {
      case 'M':
        if (nums.length >= 2) {
          x = nums[0];
          y = nums[1];
          path.moveTo(x, y);
        }
        break;
      case 'm':
        if (nums.length >= 2) {
          x += nums[0];
          y += nums[1];
          path.moveTo(x, y);
        }
        break;
      case 'L':
        if (nums.length >= 2) {
          x = nums[0];
          y = nums[1];
          path.lineTo(x, y);
        }
        break;
      case 'l':
        if (nums.length >= 2) {
          x += nums[0];
          y += nums[1];
          path.lineTo(x, y);
        }
        break;
      case 'Q':
        if (nums.length >= 4) {
          path.quadraticBezierTo(nums[0], nums[1], nums[2], nums[3]);
          x = nums[2];
          y = nums[3];
        }
        break;
      case 'q':
        if (nums.length >= 4) {
          path.quadraticBezierTo(x + nums[0], y + nums[1], x + nums[2], y + nums[3]);
          x += nums[2];
          y += nums[3];
        }
        break;
      case 'C':
        if (nums.length >= 6) {
          path.cubicTo(nums[0], nums[1], nums[2], nums[3], nums[4], nums[5]);
          x = nums[4];
          y = nums[5];
        }
        break;
      case 'c':
        if (nums.length >= 6) {
          path.cubicTo(x + nums[0], y + nums[1], x + nums[2], y + nums[3], x + nums[4], y + nums[5]);
          x += nums[4];
          y += nums[5];
        }
        break;
      case 'Z':
      case 'z':
        path.close();
        break;
    }
  }

  return path;
}

/// Pre-parsed viseme paths (from your SVG timeline)
class Visemes {
  static final Map<String, VisemeData> _cache = {};

  static const _pathData = {
    'x': {
      'mouth': 'M 0,0 Q 0,-20 20,-20 Q 40,-20 40,0 Q 40,20 20,20 Q 0,20 0,0 Z',
      'inner': 'M 0,5 Q 0,-10 15,-10 Q 30,-10 30,5 Q 30,15 15,15 Q 0,15 0,5 Z',
      'teeth': 0.0,
      'tongue': 0.0,
    },
    'a': {
      'mouth': 'M 0,0 Q 0,-30 20,-30 Q 40,-30 40,0 Q 40,50 20,50 Q 0,50 0,0 Z',
      'inner': 'M 0,10 Q 0,-15 15,-15 Q 30,-15 30,10 Q 30,40 15,40 Q 0,40 0,10 Z',
      'teeth': 0.0,
      'tongue': 0.0,
    },
    'm': {
      'mouth': 'M 0,0 Q 0,-5 20,-5 Q 40,-5 40,0 Q 40,5 20,5 Q 0,5 0,0 Z',
      'inner': 'M 0,0 Q 0,-2 15,-2 Q 30,-2 30,0 Q 30,2 15,2 Q 0,2 0,0 Z',
      'teeth': 0.0,
      'tongue': 0.0,
    },
    'e': {
      'mouth': 'M 0,0 Q 0,-25 20,-25 Q 40,-25 40,0 Q 40,15 20,15 Q 0,15 0,0 Z',
      'inner': 'M 0,5 Q 0,-12 15,-12 Q 30,-12 30,5 Q 30,10 15,10 Q 0,10 0,5 Z',
      'teeth': 0.0,
      'tongue': 0.0,
    },
    'f': {
      'mouth': 'M 0,0 Q 0,-8 20,-8 Q 40,-8 40,0 Q 40,8 20,8 Q 0,8 0,0 Z',
      'inner': 'M 0,2 Q 0,-4 15,-4 Q 30,-4 30,2 Q 30,4 15,4 Q 0,4 0,2 Z',
      'teeth': 1.0,
      'tongue': 0.0,
    },
    'i': {
      'mouth': 'M 0,0 Q 0,-22 20,-22 Q 40,-22 40,0 Q 40,10 20,10 Q 0,10 0,0 Z',
      'inner': 'M 0,3 Q 0,-10 15,-10 Q 30,-10 30,3 Q 30,6 15,6 Q 0,6 0,3 Z',
      'teeth': 0.0,
      'tongue': 0.0,
    },
    'o': {
      'mouth': 'M 0,0 Q 0,-20 20,-20 Q 40,-20 40,0 Q 40,35 20,35 Q 0,35 0,0 Z',
      'inner': 'M 0,8 Q 0,-10 15,-10 Q 30,-10 30,8 Q 30,25 15,25 Q 0,25 0,8 Z',
      'teeth': 0.0,
      'tongue': 0.0,
    },
    'u': {
      'mouth': 'M 0,0 Q 0,-15 20,-15 Q 40,-15 40,0 Q 40,25 20,25 Q 0,25 0,0 Z',
      'inner': 'M 0,8 Q 0,-7 15,-7 Q 30,-7 30,8 Q 30,18 15,18 Q 0,18 0,8 Z',
      'teeth': 0.0,
      'tongue': 0.8,
    },
    'l': {
      'mouth': 'M 0,0 Q 0,-18 20,-18 Q 40,-18 40,0 Q 40,20 20,20 Q 0,20 0,0 Z',
      'inner': 'M 0,5 Q 0,-8 15,-8 Q 30,-8 30,5 Q 30,12 15,12 Q 0,12 0,5 Z',
      'teeth': 0.0,
      'tongue': 0.5,
    },
  };

  static VisemeData get(String viseme) {
    final key = viseme.toLowerCase();
    if (_cache.containsKey(key)) return _cache[key]!;

    final data = _pathData[key] ?? _pathData['x']!;
    final result = VisemeData(
      mouthPath: parseSvgPath(data['mouth'] as String),
      innerPath: parseSvgPath(data['inner'] as String),
      teethOpacity: (data['teeth'] as num).toDouble(),
      tongueOpacity: (data['tongue'] as num).toDouble(),
    );
    _cache[key] = result;
    return result;
  }

  /// Interpolate between two visemes (for smooth transitions)
  static VisemeData lerp(String from, String to, double t) {
    // For now, just snap at 0.5 - could implement path morphing later
    return t < 0.5 ? get(from) : get(to);
  }
}

/// CustomPainter that draws mouth viseme
class MouthPainter extends CustomPainter {
  final String viseme;
  final Color mouthColor;
  final Color innerColor;
  final Color teethColor;
  final Color tongueColor;

  MouthPainter({
    required this.viseme,
    this.mouthColor = const Color(0xFF8B4513),
    this.innerColor = const Color(0xFF1A1A1A),
    this.teethColor = Colors.white,
    this.tongueColor = const Color(0xFFFF6B6B),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final data = Visemes.get(viseme);

    // Scale to fit size (paths are ~40x80 units)
    final scaleX = size.width / 50;
    final scaleY = size.height / 90;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale, scale);
    canvas.translate(-20, 0); // Center the 40-wide path

    // Draw outer mouth
    final mouthPaint = Paint()
      ..color = mouthColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(data.mouthPath, mouthPaint);

    // Draw mouth stroke
    final strokePaint = Paint()
      ..color = mouthColor.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(data.mouthPath, strokePaint);

    // Draw inner mouth (dark)
    final innerPaint = Paint()
      ..color = innerColor.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    canvas.drawPath(data.innerPath, innerPaint);

    // Draw teeth if visible
    if (data.teethOpacity > 0) {
      final teethPaint = Paint()
        ..color = teethColor.withOpacity(data.teethOpacity * 0.9)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-15, -3, 30, 10),
          const Radius.circular(2),
        ),
        teethPaint,
      );
    }

    // Draw tongue if visible
    if (data.tongueOpacity > 0) {
      final tonguePaint = Paint()
        ..color = tongueColor.withOpacity(data.tongueOpacity * 0.8)
        ..style = PaintingStyle.fill;
      canvas.drawOval(Rect.fromCenter(center: const Offset(0, 15), width: 25, height: 15), tonguePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(MouthPainter oldDelegate) => viseme != oldDelegate.viseme;
}

/// Widget wrapper for MouthPainter
class MouthWidget extends StatelessWidget {
  final String viseme;
  final double width;
  final double height;
  final Color? mouthColor;

  const MouthWidget({
    super.key,
    required this.viseme,
    this.width = 80,
    this.height = 100,
    this.mouthColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: MouthPainter(
        viseme: viseme,
        mouthColor: mouthColor ?? const Color(0xFF8B4513),
      ),
    );
  }
}
