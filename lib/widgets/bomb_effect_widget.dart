// widgets/bomb_effect_widget.dart
import 'package:flutter/material.dart';

/// Widget to show bomb explosion effect
class BombExplosionOverlay extends StatefulWidget {
  final int startRow;
  final int startCol;
  final int cellsDestroyed;
  final VoidCallback onComplete;

  const BombExplosionOverlay({
    Key? key,
    required this.startRow,
    required this.startCol,
    required this.cellsDestroyed,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<BombExplosionOverlay> createState() => _BombExplosionOverlayState();
}

class _BombExplosionOverlayState extends State<BombExplosionOverlay>
    with TickerProviderStateMixin {
  late AnimationController _explosionController;
  late AnimationController _shakeController;
  late Animation<double> _explosionAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _explosionController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _shakeController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );

    _explosionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _explosionController, curve: Curves.easeOut),
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticInOut),
    );

    // Start animations
    _explosionController.forward();
    _shakeController.repeat(reverse: true);

    // Complete after animation
    _explosionController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(Duration(milliseconds: 500), () {
          widget.onComplete();
        });
      }
    });
  }

  @override
  void dispose() {
    _explosionController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_explosionAnimation, _shakeAnimation]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            _shakeAnimation.value * 10 * (0.5 - _explosionAnimation.value),
            0,
          ),
          child: Container(
            color: Colors.red.withOpacity(0.3 * (1 - _explosionAnimation.value)),
            child: Center(
              child: Transform.scale(
                scale: 0.5 + (_explosionAnimation.value * 1.5),
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orange.withOpacity(0.8 * (1 - _explosionAnimation.value)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5 * (1 - _explosionAnimation.value)),
                        blurRadius: 50 * _explosionAnimation.value,
                        spreadRadius: 20 * _explosionAnimation.value,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '💥',
                          style: TextStyle(
                            fontSize: 48 + (20 * _explosionAnimation.value),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'BOMB!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black,
                                offset: Offset(2, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        if (widget.cellsDestroyed > 0) ...[
                          SizedBox(height: 4),
                          Text(
                            '${widget.cellsDestroyed} cells destroyed!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(1, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Widget to highlight bomb target area
class BombTargetOverlay extends StatefulWidget {
  final int startRow;
  final int startCol;

  const BombTargetOverlay({
    Key? key,
    required this.startRow,
    required this.startCol,
  }) : super(key: key);

  @override
  State<BombTargetOverlay> createState() => _BombTargetOverlayState();
}

class _BombTargetOverlayState extends State<BombTargetOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return CustomPaint(
          painter: BombTargetPainter(
            startRow: widget.startRow,
            startCol: widget.startCol,
            opacity: _pulseAnimation.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

/// Custom painter for bomb target area
class BombTargetPainter extends CustomPainter {
  final int startRow;
  final int startCol;
  final double opacity;

  BombTargetPainter({
    required this.startRow,
    required this.startCol,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.red.withOpacity(opacity * 1.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Calculate cell size (assuming square grid)
    final cellSize = size.width / 9;

    // Draw bomb target area (3x3)
    final targetRect = Rect.fromLTWH(
      startCol * cellSize,
      startRow * cellSize,
      cellSize * 3,
      cellSize * 3,
    );

    canvas.drawRect(targetRect, paint);
    canvas.drawRect(targetRect, borderPaint);

    // Draw crosshairs
    final centerX = targetRect.center.dx;
    final centerY = targetRect.center.dy;

    final crosshairPaint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = 2;

    // Horizontal line
    canvas.drawLine(
      Offset(targetRect.left, centerY),
      Offset(targetRect.right, centerY),
      crosshairPaint,
    );

    // Vertical line
    canvas.drawLine(
      Offset(centerX, targetRect.top),
      Offset(centerX, targetRect.bottom),
      crosshairPaint,
    );
  }

  @override
  bool shouldRepaint(BombTargetPainter oldDelegate) {
    return oldDelegate.opacity != opacity;
  }
}