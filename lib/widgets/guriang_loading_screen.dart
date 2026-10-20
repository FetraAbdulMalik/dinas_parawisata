import 'dart:math' as math;

import 'package:flutter/material.dart';

class GuriangLoadingScreen extends StatefulWidget {
  const GuriangLoadingScreen({super.key});

  @override
  State<GuriangLoadingScreen> createState() => _GuriangLoadingScreenState();
}

class _GuriangLoadingScreenState extends State<GuriangLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _GarutLandscapePainter(_controller.value),
              ),
            ),
          ),
          const SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'GURIANG GARUT',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3,
                        shadows: [
                          Shadow(color: Colors.black38, blurRadius: 8),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Ngamumule sajarah jeung budaya Garut',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFF8E9C7),
                        fontSize: 13,
                        shadows: [
                          Shadow(color: Colors.black38, blurRadius: 6),
                        ],
                      ),
                    ),
                    SizedBox(height: 22),
                    SizedBox(
                      width: 180,
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor: Colors.white30,
                        color: Color(0xFFE7BD70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GarutLandscapePainter extends CustomPainter {
  const _GarutLandscapePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF183B3A),
            Color(0xFF628276),
            Color(0xFFE9B979),
          ],
        ).createShader(bounds),
    );

    final sunCenter = Offset(size.width * 0.5, size.height * 0.43);
    canvas.drawCircle(
      sunCenter,
      math.min(size.width, size.height) * 0.105,
      Paint()..color = const Color(0xFFEFCB88).withValues(alpha: 0.9),
    );

    _drawMountain(
      canvas,
      size,
      const Color(0xFF657D68),
      const [0.0, 0.30, 0.51, 0.70, 1.0],
      const [0.60, 0.24, 0.49, 0.28, 0.57],
    );
    _drawMountain(
      canvas,
      size,
      const Color(0xFF385E4B),
      const [0.0, 0.24, 0.43, 0.66, 0.83, 1.0],
      const [0.64, 0.38, 0.55, 0.32, 0.48, 0.63],
    );
    _drawMountain(
      canvas,
      size,
      const Color(0xFF214633),
      const [0.0, 0.20, 0.42, 0.61, 0.81, 1.0],
      const [0.72, 0.55, 0.69, 0.48, 0.65, 0.72],
    );

    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.60 + i * 0.055);
      final drift = (progress - 0.5) * size.width * (i.isEven ? 0.06 : -0.06);
      final mistPaint = Paint()
        ..color = const Color(0xFFDDE4D3).withValues(alpha: 0.15 - i * 0.025)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13 - i * 2;
      final mist = Path()
        ..moveTo(-size.width * 0.1 + drift, y)
        ..cubicTo(
          size.width * 0.22 + drift,
          y - 19,
          size.width * 0.55 + drift,
          y + 15,
          size.width * 1.1 + drift,
          y - 8,
        );
      canvas.drawPath(mist, mistPaint);
    }
  }

  void _drawMountain(
    Canvas canvas,
    Size size,
    Color color,
    List<double> xFractions,
    List<double> yFractions,
  ) {
    final path = Path()..moveTo(0, size.height);
    for (var i = 0; i < xFractions.length; i++) {
      path.lineTo(
        size.width * xFractions[i],
        size.height * yFractions[i],
      );
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_GarutLandscapePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
