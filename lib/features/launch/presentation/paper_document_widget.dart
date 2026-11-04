import 'package:flutter/material.dart';

/// A paper document widget that animates a dog-ear fold and reveals
/// a bold PDF badge, representing the transformation from paper to PDF.
class PaperDocumentWidget extends StatelessWidget {
  final double foldProgress; // 0.0 (flat paper) to 1.0 (folded PDF)
  final bool isDark;

  const PaperDocumentWidget({
    super.key,
    required this.foldProgress,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    const width = 74.0;
    const height = 98.0;

    final paperBg = isDark ? const Color(0xFF222222) : const Color(0xFFFFFFFF);
    final borderColor = isDark ? const Color(0xFF555555) : const Color(0xFF1E1E1E);
    final lineColors = isDark ? const Color(0xFF444444) : const Color(0xFFE0E0E0);
    final foldFlapColor = isDark ? const Color(0xFF333333) : const Color(0xFFEDEDED);

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _PaperPainter(
          foldProgress: foldProgress,
          paperColor: paperBg,
          borderColor: borderColor,
          foldFlapColor: foldFlapColor,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 16, 10, 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // PDF Badge (scales & fades in as paper folds)
              Opacity(
                opacity: foldProgress.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.6 + (0.4 * foldProgress.clamp(0.0, 1.0)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFFE53935) : const Color(0xFFD32F2F),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'PDF',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10.5,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Document text placeholder lines
              Container(
                height: 3,
                width: 44,
                decoration: BoxDecoration(
                  color: lineColors,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                height: 3,
                width: 32,
                decoration: BoxDecoration(
                  color: lineColors,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                height: 3,
                width: 38,
                decoration: BoxDecoration(
                  color: lineColors,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaperPainter extends CustomPainter {
  final double foldProgress;
  final Color paperColor;
  final Color borderColor;
  final Color foldFlapColor;

  _PaperPainter({
    required this.foldProgress,
    required this.paperColor,
    required this.borderColor,
    required this.foldFlapColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double radius = 6.0;
    final double maxFold = 20.0 * foldProgress.clamp(0.0, 1.0);

    final fillPaint = Paint()
      ..color = paperColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final path = Path();
    path.moveTo(radius, 0);

    if (maxFold > 0) {
      // Top edge up to fold start
      path.lineTo(size.width - maxFold, 0);
      // Slanted fold edge to right side
      path.lineTo(size.width, maxFold);
    } else {
      path.lineTo(size.width - radius, 0);
      path.arcToPoint(Offset(size.width, radius), radius: const Radius.circular(radius));
    }

    // Right edge
    path.lineTo(size.width, size.height - radius);
    path.arcToPoint(Offset(size.width - radius, size.height), radius: const Radius.circular(radius));

    // Bottom edge
    path.lineTo(radius, size.height);
    path.arcToPoint(Offset(0, size.height - radius), radius: const Radius.circular(radius));

    // Left edge
    path.lineTo(0, radius);
    path.arcToPoint(Offset(radius, 0), radius: const Radius.circular(radius));
    path.close();

    // Draw shadow under paper
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path.shift(const Offset(0, 4)), shadowPaint);

    // Draw paper body
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);

    // Draw the triangular folded corner flap
    if (maxFold > 1) {
      final flapPath = Path();
      flapPath.moveTo(size.width - maxFold, 0);
      flapPath.lineTo(size.width - maxFold, maxFold);
      flapPath.lineTo(size.width, maxFold);
      flapPath.close();

      final flapPaint = Paint()
        ..color = foldFlapColor
        ..style = PaintingStyle.fill;

      canvas.drawPath(flapPath, flapPaint);
      canvas.drawPath(flapPath, borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PaperPainter oldDelegate) {
    return oldDelegate.foldProgress != foldProgress ||
        oldDelegate.paperColor != paperColor ||
        oldDelegate.borderColor != borderColor;
  }
}
