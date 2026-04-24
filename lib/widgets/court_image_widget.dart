import 'package:flutter/material.dart';
import '../models/court.dart';

// Color schemes per court
const _courtColors = {
  'c1': [Color(0xFF1565C0), Color(0xFF0D47A1)], // blue indoor
  'c2': [Color(0xFF1565C0), Color(0xFF0D47A1)], // green outdoor
  'c3': [Color(0xFF6A1B9A), Color(0xFF4A148C)], // purple VIP
  'c4': [Color(0xFF00695C), Color(0xFF004D40)], // teal outdoor
};

class CourtImageWidget extends StatelessWidget {
  final Court court;
  final double height;
  final bool showLabel;

  const CourtImageWidget({
    super.key,
    required this.court,
    this.height = 160,
    this.showLabel = true,
  });

  List<Color> get _colors =>
      _courtColors[court.id] ??
      [const Color(0xFF1565C0), const Color(0xFF0D47A1)];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient background (court surface)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Court lines drawn on canvas
            CustomPaint(painter: _CourtTopDownPainter()),
            // Bottom overlay for label
            if (showLabel)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.65),
                        Colors.transparent,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        court.isIndoor ? Icons.home_work : Icons.wb_sunny,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        court.isIndoor ? 'Couvert' : 'Extérieur',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CourtTopDownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final thick = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    const px = 18.0; // horizontal padding
    const py = 14.0; // vertical padding

    final left = px;
    final right = w - px;
    final top = py;
    final bottom = h - py;
    final cx = w / 2;
    final cy = h / 2;

    // Outer court boundary
    canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), thick);

    // Center net (horizontal thick line)
    canvas.drawLine(Offset(left, cy), Offset(right, cy), thick);

    // Center vertical line (full height)
    canvas.drawLine(Offset(cx, top), Offset(cx, bottom), line);

    // Service lines — at 30% from each end
    final sy1 = top + (bottom - top) * 0.30;
    final sy2 = bottom - (bottom - top) * 0.30;
    canvas.drawLine(Offset(left, sy1), Offset(right, sy1), line);
    canvas.drawLine(Offset(left, sy2), Offset(right, sy2), line);

    // Small center mark at net
    canvas.drawLine(
      Offset(cx - 8, cy),
      Offset(cx + 8, cy),
      Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..strokeWidth = 3.5,
    );

    // Glass walls hint (dashed corners)
    final corner = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Top-left corner box
    canvas.drawRect(
        Rect.fromLTWH(left, top, (right - left) * 0.12, (bottom - top) * 0.12),
        corner);
    // Top-right
    canvas.drawRect(
        Rect.fromLTWH(right - (right - left) * 0.12, top,
            (right - left) * 0.12, (bottom - top) * 0.12),
        corner);
    // Bottom-left
    canvas.drawRect(
        Rect.fromLTWH(left, bottom - (bottom - top) * 0.12,
            (right - left) * 0.12, (bottom - top) * 0.12),
        corner);
    // Bottom-right
    canvas.drawRect(
        Rect.fromLTWH(right - (right - left) * 0.12,
            bottom - (bottom - top) * 0.12,
            (right - left) * 0.12,
            (bottom - top) * 0.12),
        corner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
