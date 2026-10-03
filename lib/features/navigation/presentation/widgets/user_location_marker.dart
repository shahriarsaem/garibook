import 'dart:math' as math;
import 'package:flutter/material.dart';

class UserLocationMarker extends StatefulWidget {
  final double bearing;
  final double accuracy;

  const UserLocationMarker({
    super.key,
    this.bearing = 0.0,
    this.accuracy = 0.0,
  });

  @override
  State<UserLocationMarker> createState() => _UserLocationMarkerState();
}

class _UserLocationMarkerState extends State<UserLocationMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulse ripple effect
            Container(
              width: 48 * _pulseAnimation.value,
              height: 48 * _pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(
                  alpha: (1.0 - _pulseAnimation.value) * 0.35,
                ),
              ),
            ),
            // Outer white ring with shadow
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                // Inner primary dot
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor,
                  ),
                ),
              ),
            ),
            // Heading arrow if bearing is set (> 0)
            if (widget.bearing > 0)
              Transform.rotate(
                angle: widget.bearing * (math.pi / 180),
                child: Transform.translate(
                  offset: const Offset(0, -18),
                  child: Icon(
                    Icons.navigation,
                    size: 14,
                    color: primaryColor,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
