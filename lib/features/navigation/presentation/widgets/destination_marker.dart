import 'package:flutter/material.dart';
import '../../../../core/constants/app_strings.dart';

/// A distinct, theme-styled destination pin marker
class DestinationMarker extends StatefulWidget {
  final Color? color;

  const DestinationMarker({
    super.key,
    this.color,
  });

  @override
  State<DestinationMarker> createState() => _DestinationMarkerState();
}

class _DestinationMarkerState extends State<DestinationMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pinColor = widget.color ?? theme.colorScheme.error;

    return ScaleTransition(
      scale: _scaleAnimation,
      alignment: Alignment.bottomCenter,
      child: Tooltip(
        message: AppStrings.destination,
        child: SizedBox(
          width: 44,
          height: 48,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              // Ground contact shadow
              Positioned(
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              // Pin body
              Positioned(
                top: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: pinColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: pinColor.withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white,
                          width: 2.5,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.flag_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                    // Pointer triangle
                    CustomPaint(
                      size: const Size(10, 8),
                      painter: _PinPointPainter(color: pinColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinPointPainter extends CustomPainter {
  final Color color;

  const _PinPointPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PinPointPainter oldDelegate) =>
      oldDelegate.color != color;
}
