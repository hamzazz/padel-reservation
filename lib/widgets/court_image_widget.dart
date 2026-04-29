import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/court.dart';

const _courtColors = {
  'c1': [Color(0xFF1565C0), Color(0xFF0D47A1)],
  'c2': [Color(0xFF1565C0), Color(0xFF0D47A1)],
  'c3': [Color(0xFF6A1B9A), Color(0xFF4A148C)],
  'c4': [Color(0xFF00695C), Color(0xFF004D40)],
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
        width: double.infinity,
        child: Stack(
          children: [
            // ── Image ou gradient ──────────────────────────────────
            Positioned.fill(child: _buildImage()),

            // ── Label en bas ───────────────────────────────────────
            if (showLabel)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  Widget _buildImage() {
    final url = court.imageUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: height,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, __) => _gradientFallback(),
        errorWidget: (_, __, ___) => _gradientFallback(),
      );
    }
    return _gradientFallback();
  }

  Widget _gradientFallback() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        CustomPaint(painter: _CourtTopDownPainter()),
      ],
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
    const px = 18.0;
    const py = 14.0;

    final left = px;
    final right = w - px;
    final top = py;
    final bottom = h - py;
    final cx = w / 2;
    final cy = h / 2;

    canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), thick);
    canvas.drawLine(Offset(left, cy), Offset(right, cy), thick);
    canvas.drawLine(Offset(cx, top), Offset(cx, bottom), line);

    final sy1 = top + (bottom - top) * 0.30;
    final sy2 = bottom - (bottom - top) * 0.30;
    canvas.drawLine(Offset(left, sy1), Offset(right, sy1), line);
    canvas.drawLine(Offset(left, sy2), Offset(right, sy2), line);

    canvas.drawLine(
      Offset(cx - 8, cy),
      Offset(cx + 8, cy),
      Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..strokeWidth = 3.5,
    );

    final corner = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(
        Rect.fromLTWH(left, top, (right - left) * 0.12, (bottom - top) * 0.12),
        corner);
    canvas.drawRect(
        Rect.fromLTWH(right - (right - left) * 0.12, top,
            (right - left) * 0.12, (bottom - top) * 0.12),
        corner);
    canvas.drawRect(
        Rect.fromLTWH(left, bottom - (bottom - top) * 0.12,
            (right - left) * 0.12, (bottom - top) * 0.12),
        corner);
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
