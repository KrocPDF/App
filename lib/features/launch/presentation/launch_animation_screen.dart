import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'paper_document_widget.dart';

/// Custom Easing Curves written as Curve subclasses per specification:
/// easeOutBack(p) = 1 + 2.4·(p−1)³ + 1.4·(p−1)²
class EaseOutBackCurve extends Curve {
  const EaseOutBackCurve();

  @override
  double transformInternal(double t) {
    final p = t.clamp(0.0, 1.0);
    final m = p - 1.0;
    return 1.0 + 2.4 * m * m * m + 1.4 * m * m;
  }
}

/// easeOutCubic(p) = 1 − (1−p)³
class EaseOutCubicCurve extends Curve {
  const EaseOutCubicCurve();

  @override
  double transformInternal(double t) {
    final p = t.clamp(0.0, 1.0);
    final m = 1.0 - p;
    return 1.0 - (m * m * m);
  }
}

/// easeInOutQuad(p) = p < 0.5 ? 2p² : 1 − (−2p+2)²/2
class EaseInOutQuadCurve extends Curve {
  const EaseInOutQuadCurve();

  @override
  double transformInternal(double t) {
    final p = t.clamp(0.0, 1.0);
    if (p < 0.5) {
      return 2.0 * p * p;
    } else {
      final diff = -2.0 * p + 2.0;
      return 1.0 - (diff * diff) / 2.0;
    }
  }
}

/// Computes the exact mathematical state of the launch sequence at second [t] (0.0 to 4.2).
/// Every value is a pure function of t.
class LaunchTimelineState {
  final double t;
  final double top;
  final double fold;
  final double textLinesOpacity;
  final double pdfBadgeOpacity;
  final double crocX;
  final double crocScale;
  final double mouthA;
  final double iconRotate;
  final double iconScale;
  final double iconXOffset;
  final bool wordmarkVisible;
  final double revealX;
  final double sceneOpacity;

  const LaunchTimelineState({
    required this.t,
    required this.top,
    required this.fold,
    required this.textLinesOpacity,
    required this.pdfBadgeOpacity,
    required this.crocX,
    required this.crocScale,
    required this.mouthA,
    required this.iconRotate,
    required this.iconScale,
    required this.iconXOffset,
    required this.wordmarkVisible,
    required this.revealX,
    required this.sceneOpacity,
  });

  static const easeOutBackCurve = EaseOutBackCurve();
  static const easeOutCubicCurve = EaseOutCubicCurve();
  static const easeInOutQuadCurve = EaseInOutQuadCurve();

  static double _clamp01(double v) => v.clamp(0.0, 1.0);
  static double _lerp(double a, double b, double p) => a + (b - a) * p;

  factory LaunchTimelineState.compute(double t) {
    final clampedT = t.clamp(0.0, 4.2);

    // 0 to 0.8: Paper drops
    // top = lerp(−200, 226, easeOutBack(clamp(t/0.8))) (226 = 266 − 40)
    final double top = _lerp(
      -200.0,
      226.0,
      easeOutBackCurve.transform(_clamp01(clampedT / 0.8)),
    );

    // 0.8 to 1.4: Corner folds
    // fold = clamp((t−0.8)/0.6) × 18
    final double fold = _clamp01((clampedT - 0.8) / 0.6) * 18.0;

    // 0.9 to 1.3: Text lines fade in
    // opacity = clamp((t−0.9)/0.4) × 0.9
    final double textLinesOpacity = _clamp01((clampedT - 0.9) / 0.4) * 0.9;

    // 1.0 to 1.4: “PDF” badge fades in
    // opacity = clamp((t−1.0)/0.4)
    final double pdfBadgeOpacity = _clamp01((clampedT - 1.0) / 0.4);

    // Crocodile X translation
    // 1.0 to 1.6: Croc enters: x = lerp(−230, −30, easeOutCubic(clamp((t−1.0)/0.6)))
    // 1.6 to 1.85: Lunge: x = lerp(−30, 0, clamp((t−1.6)/0.25))
    // 1.85 to 3.1: Croc exits right: x = lerp(0, 420, easeInOutQuad(clamp((t−1.85)/1.25)))
    final double crocX;
    if (clampedT < 1.0) {
      crocX = -230.0;
    } else if (clampedT <= 1.6) {
      crocX = _lerp(
        -230.0,
        -30.0,
        easeOutCubicCurve.transform(_clamp01((clampedT - 1.0) / 0.6)),
      );
    } else if (clampedT <= 1.85) {
      crocX = _lerp(-30.0, 0.0, _clamp01((clampedT - 1.6) / 0.25));
    } else if (clampedT <= 3.1) {
      crocX = _lerp(
        0.0,
        420.0,
        easeInOutQuadCurve.transform(_clamp01((clampedT - 1.85) / 1.25)),
      );
    } else {
      crocX = 420.0;
    }

    // 1.6 to 1.95: Scale pulse
    // scale = 1 + 0.06·sin(clamp((t−1.6)/0.35)·π), otherwise 1
    final double crocScale;
    if (clampedT >= 1.6 && clampedT <= 1.95) {
      crocScale = 1.0 + 0.06 * math.sin(_clamp01((clampedT - 1.6) / 0.35) * math.pi);
    } else {
      crocScale = 1.0;
    }

    // Mouth Opening parameter A:
    // 1.0 to 1.62: Mouth opens: A = easeOutCubic(clamp((t−1.0)/0.45)) (reaches 1 at 1.45s and holds until 1.62s)
    // 1.62 to 1.85: Jaws snap shut: A = 1 − clamp((t−1.62)/0.23)²
    // between 1.85 and 1.88: A = 0
    // from 1.88: Chewing: A = 0.1 × abs(sin((t − 1.88) × 12)) × (1 − clamp((t − 1.88) / 0.6))
    // A = 0 from 2.48 onward
    final double mouthA;
    if (clampedT < 1.0) {
      mouthA = 0.0;
    } else if (clampedT <= 1.62) {
      mouthA = easeOutCubicCurve.transform(_clamp01((clampedT - 1.0) / 0.45));
    } else if (clampedT <= 1.85) {
      final p = _clamp01((clampedT - 1.62) / 0.23);
      mouthA = 1.0 - (p * p);
    } else if (clampedT < 1.88) {
      mouthA = 0.0;
    } else if (clampedT < 2.48) {
      final chewT = clampedT - 1.88;
      mouthA = 0.1 * math.sin(chewT * 12.0).abs() * (1.0 - _clamp01(chewT / 0.6));
    } else {
      mouthA = 0.0;
    }

    // 1.7 to 1.9: Icon is bitten
    // e = clamp((t−1.7)/0.2); icon rotate = −10°·e, scale = 1 − 0.15·e
    final double e = _clamp01((clampedT - 1.7) / 0.2);
    final double iconRotate = -10.0 * (math.pi / 180.0) * e;
    final double iconScale = 1.0 - 0.15 * e;

    // from 1.85: Icon carried: icon x offset = croc x (0 before 1.85)
    final double iconXOffset = clampedT >= 1.85 ? crocX : 0.0;

    // 1.85 to 3.1: Wordmark revealed
    // revealX = clamp(60 + (x+195−195)·0.75, 60, 330); hidden entirely before 1.85
    final bool wordmarkVisible = clampedT >= 1.85;
    final double revealX = wordmarkVisible
        ? (60.0 + crocX * 0.75).clamp(60.0, 330.0)
        : 0.0;

    // 3.8 to 4.2: Fade out
    // scene opacity = 1 − clamp((t−3.8)/0.4)
    final double sceneOpacity;
    if (clampedT < 3.8) {
      sceneOpacity = 1.0;
    } else {
      sceneOpacity = 1.0 - _clamp01((clampedT - 3.8) / 0.4);
    }

    return LaunchTimelineState(
      t: clampedT,
      top: top,
      fold: fold,
      textLinesOpacity: textLinesOpacity,
      pdfBadgeOpacity: pdfBadgeOpacity,
      crocX: crocX,
      crocScale: crocScale,
      mouthA: mouthA,
      iconRotate: iconRotate,
      iconScale: iconScale,
      iconXOffset: iconXOffset,
      wordmarkVisible: wordmarkVisible,
      revealX: revealX,
      sceneOpacity: sceneOpacity,
    );
  }
}

/// Branded launch animation screen driven by a single 4200ms AnimationController.
class LaunchAnimationScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final double? debugT;

  const LaunchAnimationScreen({
    super.key,
    required this.onComplete,
    this.debugT,
  });

  @override
  State<LaunchAnimationScreen> createState() => _LaunchAnimationScreenState();
}

class _LaunchAnimationScreenState extends State<LaunchAnimationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _watchdogTimer;
  Timer? _reducedMotionTimer;
  bool _isFinished = false;
  bool _isReducedMotion = false;

  @override
  void initState() {
    super.initState();

    try {
      if (widget.debugT == null) {
        // 5.5s watchdog safety net (only when running full animation live)
        _watchdogTimer = Timer(const Duration(milliseconds: 5500), _finish);
      }

      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 4200),
      );

      _controller.addStatusListener((status) {
        if (status == AnimationStatus.completed && widget.debugT == null) {
          _finish();
        }
      });

      if (widget.debugT != null) {
        _controller.value = (widget.debugT! / 4.2).clamp(0.0, 1.0);
      }
    } catch (_) {
      _finish();
    }
  }

  @override
  void didUpdateWidget(LaunchAnimationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.debugT != null) {
      _controller.stop();
      _controller.value = (widget.debugT! / 4.2).clamp(0.0, 1.0);
      _watchdogTimer?.cancel();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.debugT != null) {
      _controller.stop();
      _controller.value = (widget.debugT! / 4.2).clamp(0.0, 1.0);
      _watchdogTimer?.cancel();
    } else if (disableAnimations && !_isReducedMotion) {
      _isReducedMotion = true;
      _reducedMotionTimer?.cancel();
      _reducedMotionTimer = Timer(const Duration(milliseconds: 800), _finish);
    } else if (!_isReducedMotion && !_controller.isAnimating && !_controller.isCompleted) {
      _controller.forward();
    }
  }

  void _finish() {
    if (_isFinished) return;
    _isFinished = true;
    _watchdogTimer?.cancel();
    _reducedMotionTimer?.cancel();
    if (mounted) {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _watchdogTimer?.cancel();
    _reducedMotionTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final logoAsset = isDark ? 'assets/splash/logo_dark.png' : 'assets/splash/logo.png';
    final textColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111111);
    final subtextColor = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575);

    // Reduced motion view
    if (_isReducedMotion) {
      return Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _finish,
          child: Container(
            color: bgColor,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    logoAsset,
                    width: 90,
                    height: 90,
                    errorBuilder: (context, error, stackTrace) {
                      WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
                      return const SizedBox.shrink();
                    },
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'KrocPDF',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fast. Private. On-device.',
                    style: TextStyle(
                      color: subtextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = widget.debugT ?? (_controller.value * 4.2);
            final state = LaunchTimelineState.compute(t);

            return Opacity(
              opacity: state.sceneOpacity.clamp(0.0, 1.0),
              child: Container(
                color: bgColor,
                child: Center(
                  child: SizedBox(
                    width: 360,
                    height: 600,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 1. Wordmark & Tagline (Reveals behind crocodile from 1.85s to 3.1s, holds to 3.8s)
                        if (state.wordmarkVisible)
                          Positioned(
                            left: 15.0,
                            top: 242.0,
                            width: 330.0,
                            child: ClipRect(
                              clipper: _WordmarkRevealClipper(state.revealX),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'KrocPDF',
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Fast. Private. On-device.',
                                    style: TextStyle(
                                      color: subtextColor,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // 2. Paper Document Icon (Drops 0-0.8s, folds 0.8-1.4s, bitten 1.7-1.9s, carried from 1.85s)
                        Positioned(
                          left: 154.0 + state.iconXOffset,
                          top: state.top,
                          child: Transform.rotate(
                            angle: state.iconRotate,
                            child: Transform.scale(
                              scale: state.iconScale,
                              child: PaperDocumentWidget(
                                fold: state.fold,
                                textLinesOpacity: state.textLinesOpacity,
                                pdfBadgeOpacity: state.pdfBadgeOpacity,
                                isDark: isDark,
                              ),
                            ),
                          ),
                        ),

                        // 3. Crocodile (Enters from left 1.0-1.6s, mouth opens, lunges 1.6-1.85s, bites & carries icon, exits right)
                        Positioned(
                          left: state.crocX,
                          top: 142.0, // Aligns jaw cleft center with paper center Y = 266.0 (142 + 124 = 266)
                          child: Transform.scale(
                            scale: state.crocScale,
                            origin: const Offset(60.5, 116.4),
                            child: SizedBox(
                              width: 200,
                              height: 200,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // 1. Lower Jaw (rotates +16° * A around hinge (60.5, 116.4))
                                  Transform.rotate(
                                    angle: 16.0 * (math.pi / 180.0) * state.mouthA,
                                    origin: const Offset(60.5, 116.4),
                                    child: ClipPath(
                                      clipper: const _LowerJawClipper(),
                                      child: Image.asset(
                                        logoAsset,
                                        width: 200,
                                        height: 200,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                    ),
                                  ),

                                  // 2. Upper Head (Stationary: 3 crests, skull, eye, snout, top teeth)
                                  ClipPath(
                                    clipper: const _UpperHeadClipper(),
                                    child: Image.asset(
                                      logoAsset,
                                      width: 200,
                                      height: 200,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
                                        return const SizedBox.shrink();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Cuts the stationary upper head of the crocodile (all 3 back crests,
/// the skull, eye, snout ridge, and top teeth) that remains rock-solid.
class _UpperHeadClipper extends CustomClipper<Path> {
  const _UpperHeadClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    final sx = size.width / 200.0;
    final sy = size.height / 200.0;

    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, 104.3 * sy);
    path.lineTo(84.0 * sx, 104.3 * sy);
    path.lineTo(60.5 * sx, 116.4 * sy);
    path.lineTo(60.5 * sx, 145.0 * sy);
    path.lineTo(0, 145.0 * sy);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Cuts the articulating lower jaw and bottom teeth along the mouth cleft.
class _LowerJawClipper extends CustomClipper<Path> {
  const _LowerJawClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    final sx = size.width / 200.0;
    final sy = size.height / 200.0;

    path.moveTo(35.0 * sx, 135.0 * sy);
    path.lineTo(60.5 * sx, 116.4 * sy);
    path.lineTo(84.0 * sx, 104.3 * sy);
    path.lineTo(size.width, 104.3 * sy);
    path.lineTo(size.width, size.height);
    path.lineTo(35.0 * sx, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Reveals the wordmark from left to right as the crocodile retreats to the right.
class _WordmarkRevealClipper extends CustomClipper<Rect> {
  final double revealWidth;

  const _WordmarkRevealClipper(this.revealWidth);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, revealWidth.clamp(0.0, size.width), size.height);
  }

  @override
  bool shouldReclip(covariant _WordmarkRevealClipper oldClipper) {
    return oldClipper.revealWidth != revealWidth;
  }
}
