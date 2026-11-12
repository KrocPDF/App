import 'package:flutter/material.dart';

/// A paper document widget matching the KrocPDF branded launch icon:
/// White sheet of paper with clean dog-ear fold, 3 text lines on top,
/// and a solid black badge with bold white "PDF" text on the bottom.
class PaperDocumentWidget extends StatelessWidget {
  final double fold; // Corner fold size in pixels (0.0 to 18.0)
  final double textLinesOpacity; // 0.0 to 0.9
  final double pdfBadgeOpacity; // 0.0 to 1.0
  final bool isDark;

  const PaperDocumentWidget({
    super.key,
    this.fold = 0.0,
    this.textLinesOpacity = 0.0,
    this.pdfBadgeOpacity = 0.0,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    const width = 62.0;
    const height = 80.0;

    // In light mode: crisp white sheet with dark border & black badge.
    // In dark mode: sleek dark card (0xFF1C1C1E) with white border & white badge,
    // ensuring maximum contrast and razor-sharp teeth definition with the white crocodile.
    final paperBg = isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF);
    final borderColor = isDark
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF1E1E1E);
    final lineColor = isDark
        ? const Color(0xFF8E8E93)
        : const Color(0xFF222222);
    final foldFlapColor = isDark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFEBEBEB);
    final badgeBg = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
    final badgeTextColor = isDark
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _PaperPainter(
          fold: fold,
          paperColor: paperBg,
          borderColor: borderColor,
          foldFlapColor: foldFlapColor,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Three placeholder text lines on top
              Opacity(
                opacity: textLinesOpacity.clamp(0.0, 1.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 2.5,
                      width: 28,
                      decoration: BoxDecoration(
                        color: lineColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 3.5),
                    Container(
                      height: 2.5,
                      width: 44,
                      decoration: BoxDecoration(
                        color: lineColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 3.5),
                    Container(
                      height: 2.5,
                      width: 44,
                      decoration: BoxDecoration(
                        color: lineColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // 2. High-contrast badge with bold "PDF" text on bottom
              Opacity(
                opacity: pdfBadgeOpacity.clamp(0.0, 1.0),
                child: Container(
                  width: 44,
                  height: 25,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(4.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'PDF',
                    style: TextStyle(
                      color: badgeTextColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.0,
                      letterSpacing: 0.5,
                      height: 1.1,
                    ),
                  ),
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
  final double fold;
  final Color paperColor;
  final Color borderColor;
  final Color foldFlapColor;

  _PaperPainter({
    required this.fold,
    required this.paperColor,
    required this.borderColor,
    required this.foldFlapColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double radius = 5.0;
    final double maxFold = fold.clamp(0.0, 18.0);

    final fillPaint = Paint()
      ..color = paperColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final path = Path();
    path.moveTo(radius, 0);

    if (maxFold > 0.5) {
      // Top edge up to fold start
      path.lineTo(size.width - maxFold, 0);
      // Slanted fold edge to right side
      path.lineTo(size.width, maxFold);
    } else {
      path.lineTo(size.width - radius, 0);
      path.arcToPoint(
        Offset(size.width, radius),
        radius: const Radius.circular(radius),
      );
    }

    // Right edge
    path.lineTo(size.width, size.height - radius);
    path.arcToPoint(
      Offset(size.width - radius, size.height),
      radius: const Radius.circular(radius),
    );

    // Bottom edge
    path.lineTo(radius, size.height);
    path.arcToPoint(
      Offset(0, size.height - radius),
      radius: const Radius.circular(radius),
    );

    // Left edge
    path.lineTo(0, radius);
    path.arcToPoint(Offset(radius, 0), radius: const Radius.circular(radius));
    path.close();

    // Draw shadow under paper for clean separation on white background
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawPath(path.shift(const Offset(0, 2)), shadowPaint);

    // Draw paper body and clean border
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);

    // Draw the triangular folded corner flap
    if (maxFold > 1.0) {
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
    return oldDelegate.fold != fold ||
        oldDelegate.paperColor != paperColor ||
        oldDelegate.borderColor != borderColor;
  }
}
