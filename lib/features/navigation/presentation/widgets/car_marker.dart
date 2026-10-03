import 'dart:math';
import 'package:flutter/material.dart';

/// Modern top-down vehicle marker widget with smooth bearing rotation,
/// headlights beam, roof, windshield, side mirrors, and subtle glow.
class CarMarker extends StatefulWidget {
  final double bearing;
  final double size;
  final Color? carColor;

  const CarMarker({
    super.key,
    required this.bearing,
    this.size = 56.0,
    this.carColor,
  });

  @override
  State<CarMarker> createState() => _CarMarkerState();
}

class _CarMarkerState extends State<CarMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  late double _currentAngle;

  @override
  void initState() {
    super.initState();
    _currentAngle = widget.bearing;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _animation = AlwaysStoppedAnimation<double>(_currentAngle);
  }

  @override
  void didUpdateWidget(covariant CarMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.bearing - oldWidget.bearing).abs() > 0.01) {
      final current = _controller.isAnimating ? _animation.value : _currentAngle;
      // Calculate shortest angular path to prevent 360-degree wrapping spin
      final diff = ((widget.bearing - (current % 360) + 540) % 360) - 180;
      if (diff.abs() > 0.1) {
        _currentAngle = current;
        _animation = Tween<double>(
          begin: _currentAngle,
          end: _currentAngle + diff,
        ).animate(CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutCubic,
        ));
        _controller.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vehicleColor = widget.carColor ?? theme.colorScheme.primary;

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _animation.value * (pi / 180.0),
              alignment: Alignment.center,
              child: child,
            );
          },
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _CarPainter(
              carColor: vehicleColor,
              glowColor: vehicleColor.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}

class _CarPainter extends CustomPainter {
  final Color carColor;
  final Color glowColor;

  _CarPainter({
    required this.carColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Center the coordinate origin in the marker box
    canvas.translate(size.width / 2, size.height / 2);

    // 1. Subtle pulsing radar/ground glow
    final glowPaint = Paint()
      ..color = glowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    canvas.drawCircle(Offset.zero, 24.0, glowPaint);

    // 2. Headlight light cones (shining forward / negative Y)
    _drawHeadlightBeams(canvas);

    // 3. Ground drop shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    final shadowRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, 2), width: 22, height: 42),
      const Radius.circular(7),
    );
    canvas.drawRRect(shadowRRect, shadowPaint);

    // 4. Tires
    final tirePaint = Paint()..color = const Color(0xFF1E2124);
    const tireWidth = 3.5;
    const tireHeight = 7.5;
    // Front-left & Front-right
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(-11.5, -11), width: tireWidth, height: tireHeight),
        const Radius.circular(1.5),
      ),
      tirePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(11.5, -11), width: tireWidth, height: tireHeight),
        const Radius.circular(1.5),
      ),
      tirePaint,
    );
    // Rear-left & Rear-right
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(-11.5, 11), width: tireWidth, height: tireHeight),
        const Radius.circular(1.5),
      ),
      tirePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(11.5, 11), width: tireWidth, height: tireHeight),
        const Radius.circular(1.5),
      ),
      tirePaint,
    );

    // 5. Side mirrors
    final mirrorPaint = Paint()..color = carColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(-12.5, -9), width: 3.5, height: 3.0),
        const Radius.circular(1.5),
      ),
      mirrorPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(12.5, -9), width: 3.5, height: 3.0),
        const Radius.circular(1.5),
      ),
      mirrorPaint,
    );

    // 6. Car body
    final bodyRect = Rect.fromCenter(center: Offset.zero, width: 22, height: 42);
    final bodyRRect = RRect.fromRectAndRadius(bodyRect, const Radius.circular(7));
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          carColor,
          HSLColor.fromColor(carColor).withLightness(
            (HSLColor.fromColor(carColor).lightness * 0.78).clamp(0.0, 1.0),
          ).toColor(),
        ],
      ).createShader(bodyRect);
    canvas.drawRRect(bodyRRect, bodyPaint);

    // Subtle edge highlight
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: 0.55);
    canvas.drawRRect(bodyRRect, borderPaint);

    // 7. Windshield (Front glass)
    final glassPaint = Paint()..color = const Color(0xFF0F172A);
    final frontGlassRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, -9), width: 16, height: 7),
      const Radius.circular(3),
    );
    canvas.drawRRect(frontGlassRRect, glassPaint);

    // Windshield reflection
    final glassGlarePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(-5, -11), const Offset(5, -7), glassGlarePaint);

    // 8. Roof / Sunroof panel
    final roofPaint = Paint()..color = const Color(0xFF1E293B);
    final roofRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, 1), width: 15, height: 11),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(roofRRect, roofPaint);

    // 9. Rear windshield
    final rearGlassRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, 10), width: 14, height: 5),
      const Radius.circular(2),
    );
    canvas.drawRRect(rearGlassRRect, glassPaint);

    // 10. Front Headlights
    final headlightPaint = Paint()..color = const Color(0xFFFFFDE7);
    canvas.drawCircle(const Offset(-6.5, -20), 2.0, headlightPaint);
    canvas.drawCircle(const Offset(6.5, -20), 2.0, headlightPaint);

    // 11. Rear Taillights
    final taillightPaint = Paint()..color = const Color(0xFFFF1744);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(-6.5, 20.5), width: 4.5, height: 2),
        const Radius.circular(1),
      ),
      taillightPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(6.5, 20.5), width: 4.5, height: 2),
        const Radius.circular(1),
      ),
      taillightPaint,
    );

    canvas.restore();
  }

  void _drawHeadlightBeams(Canvas canvas) {
    final beamPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFFFFF59D).withValues(alpha: 0.4),
          const Color(0xFFFFF59D).withValues(alpha: 0.15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(const Rect.fromLTRB(-18, -36, 18, -18));

    // Left beam
    final leftBeam = Path()
      ..moveTo(-6.5, -20)
      ..lineTo(-16.0, -36)
      ..lineTo(-1.0, -36)
      ..close();
    canvas.drawPath(leftBeam, beamPaint);

    // Right beam
    final rightBeam = Path()
      ..moveTo(6.5, -20)
      ..lineTo(1.0, -36)
      ..lineTo(16.0, -36)
      ..close();
    canvas.drawPath(rightBeam, beamPaint);
  }

  @override
  bool shouldRepaint(covariant _CarPainter oldDelegate) {
    return oldDelegate.carColor != carColor || oldDelegate.glowColor != glowColor;
  }
}
