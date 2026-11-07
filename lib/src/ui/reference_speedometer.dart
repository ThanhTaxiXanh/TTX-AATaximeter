import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Visual reference: speed gauge & speed-limit badge from supplied video.
/// This is phone UI, not an Android Auto CarAppService.
class ReferenceSpeedometer extends StatelessWidget {
  const ReferenceSpeedometer({
    super.key,
    required this.speedKmh,
    required this.speedLimitKmh,
  });

  final double speedKmh;
  final double speedLimitKmh;

  @override
  Widget build(BuildContext context) {
    final limitText = speedLimitKmh.round().toString();
    return SizedBox(
      height: 240,
      width: double.infinity,
      child: LayoutBuilder(builder: (context, constraints) {
        final width = math.min(400.0, constraints.maxWidth);
        return Center(
          child: SizedBox(
            width: width,
            height: 240,
            child: Stack(children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ArcPainter(
                    speed: speedKmh,
                    maxSpeed: math.max(80, speedLimitKmh),
                  ),
                ),
              ),
              Positioned(
                left: 0, right: 0, top: 64,
                child: Column(children: [
                  Text(speedKmh.round().toString(),
                    style: const TextStyle(
                      color: Colors.white, fontSize: 74, height: 1.1,
                      fontWeight: FontWeight.w800,
                    )),
                  const Text('km/h', style: TextStyle(
                    color: Color(0xFFFFB800), letterSpacing: 1.5,
                    fontWeight: FontWeight.w700, fontSize: 18,
                  )),
                ]),
              ),
              Positioned(
                right: 35, top: 9,
                child: Container(
                  height: 53, width: 53,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFFFF3554), width: 5),
                  ),
                  child: Center(child: FittedBox(
                    child: Text(limitText,
                      style: const TextStyle(
                        color: Colors.black, fontWeight: FontWeight.w900,
                        fontSize: 20,
                      )),
                  )),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.speed, required this.maxSpeed});
  final double speed, maxSpeed;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, 130);
    const radius = 111.0;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = const Color(0xFF1B2438)
      ..strokeWidth = 17
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawArc(rect, math.pi / 4, -math.pi * 1.5, false, track);
    final progress = (speed / maxSpeed).clamp(0.0, 1.0);
    if (progress <= 0) return;
    final active = Paint()
      ..color = const Color(0xFF00D8F0)
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawArc(rect, math.pi / 4,
      -math.pi * 1.5 * progress, false, active);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) =>
      speed != oldDelegate.speed || maxSpeed != oldDelegate.maxSpeed;
}
