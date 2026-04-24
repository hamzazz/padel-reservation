import 'package:flutter/material.dart';

class CourtPainter extends CustomPainter {
  const CourtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    const pad = 14.0;

    // Outer boundary
    canvas.drawRect(
        Rect.fromLTWH(pad, pad, w - pad * 2, h - pad * 2), linePaint);

    // Center vertical line
    canvas.drawLine(Offset(w / 2, pad), Offset(w / 2, h - pad), linePaint);

    // Service lines (horizontal)
    final sy1 = pad + (h - pad * 2) * 0.33;
    final sy2 = h - pad - (h - pad * 2) * 0.33;
    canvas.drawLine(Offset(pad, sy1), Offset(w - pad, sy1), linePaint);
    canvas.drawLine(Offset(pad, sy2), Offset(w - pad, sy2), linePaint);

    // Net (center horizontal, thicker)
    final netPaint = Paint()
      ..color = Colors.white.withOpacity(0.45)
      ..strokeWidth = 3.0;
    canvas.drawLine(Offset(pad, h / 2), Offset(w - pad, h / 2), netPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Reusable sliver app bar background with padel court
Widget buildCourtSliverBackground() {
  return Stack(
    fit: StackFit.expand,
    children: [
      Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1976D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      const CustomPaint(painter: CourtPainter()),
      Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black.withOpacity(0.45),
              Colors.transparent,
            ],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
      ),
    ],
  );
}
