import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'paper_document_widget.dart';

/// Custom Easing Curves written as Curve subclasses:
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

/// Computes the exact mathematical state of the launch sequence at second [t] (0.0 to 3.2s).
/// Sequence:
/// 1. Paper drops in middle of screen (0.0 - 0.6s)
/// 2. Converts into PDF file (0.6 - 1.0s)
/// 3. Crocodile comes from left, opens mouth, and eats that file (1.0 - 1.7s)
/// 4. Crocodile moves rightward and reveals the word "KrocPDF" (1.7 - 2.5s)
/// 5. Wordmark holds and cross-fades to Home (2.5 - 3.2s)
class LaunchTimelineState {
  final double t;
  final double paperY;
  final double paperOpacity;
  final double fold;
  final double textLinesOpacity;
  final double pdfBadgeOpacity;
  final double crocX;
  final double crocScale;
  final double mouthA;
  final double pdfScale;
  final double pdfOpacity;
  final double revealProgress;
  final double sceneOpacity;

  const LaunchTimelineState({
    required this.t,
    required this.paperY,
    required this.paperOpacity,
    required this.fold,
    required this.textLinesOpacity,
    required this.pdfBadgeOpacity,
    required this.crocX,
    required this.crocScale,
    required this.mouthA,
    required this.pdfScale,
    required this.pdfOpacity,
    required this.revealProgress,
    required this.sceneOpacity,
  });

  static const easeOutBackCurve = EaseOutBackCurve();
  static const easeOutCubicCurve = EaseOutCubicCurve();
  static const easeInOutQuadCurve = EaseInOutQuadCurve();

  static double _clamp01(double v) => v.clamp(0.0, 1.0);
  static double _lerp(double a, double b, double p) => a + (b - a) * p;

  factory LaunchTimelineState.compute(double t) {
    final clampedT = t.clamp(0.0, 3.2);

    // 1. Paper drops in from top to middle (0.0 to 0.6s)
    final double pDrop = _clamp01(clampedT / 0.6);
    final double paperY = _lerp(-240.0, 0.0, easeOutBackCurve.transform(pDrop));
    final double paperOpacity = _clamp01(clampedT / 0.15);

    // 2. Corner folds into PDF document (0.6 to 1.0s)
    final double pFold = _clamp01((clampedT - 0.6) / 0.4);
    final double fold = pFold * 18.0;
    final double textLinesOpacity = _clamp01((clampedT - 0.65) / 0.25) * 0.9;
    final double pdfBadgeOpacity = _clamp01((clampedT - 0.70) / 0.25);

    // 3. Crocodile enters from left to mouth-on-paper (1.0 to 1.5s)
    // When crocX = -20, crocodile mouth cavity perfectly centers over the PDF file
    final double crocX;
    if (clampedT < 1.0) {
      crocX = -280.0;
    } else if (clampedT <= 1.5) {
      crocX = _lerp(-280.0, -20.0, easeOutCubicCurve.transform(_clamp01((clampedT - 1.0) / 0.5)));
    } else if (clampedT <= 1.7) {
      crocX = _lerp(-20.0, -10.0, _clamp01((clampedT - 1.5) / 0.2));
    } else if (clampedT <= 2.5) {
      // Moves rightward off-screen
      crocX = _lerp(-10.0, 380.0, easeInOutQuadCurve.transform(_clamp01((clampedT - 1.7) / 0.8)));
    } else {
      crocX = 380.0;
    }

    // Mouth Opening parameter A:
    // 1.0 to 1.5s: opens wide
    // 1.5 to 1.7s: snaps shut on the file
    // 1.7 to 2.2s: chewing settle while walking off
    final double mouthA;
    if (clampedT < 1.0) {
      mouthA = 0.0;
    } else if (clampedT <= 1.5) {
      mouthA = easeOutCubicCurve.transform(_clamp01((clampedT - 1.0) / 0.45));
    } else if (clampedT <= 1.7) {
      final pShut = _clamp01((clampedT - 1.5) / 0.2);
      mouthA = 1.0 - (pShut * pShut);
    } else if (clampedT <= 2.2) {
      final chewP = _clamp01((clampedT - 1.7) / 0.5);
      mouthA = 0.15 * math.sin(chewP * 3 * math.pi).abs() * (1.0 - chewP);
    } else {
      mouthA = 0.0;
    }

    // Scale pulse on bite (1.5 to 1.75s)
    final double crocScale;
    if (clampedT >= 1.5 && clampedT <= 1.75) {
      crocScale = 1.0 + 0.08 * math.sin(_clamp01((clampedT - 1.5) / 0.25) * math.pi);
    } else {
      crocScale = 1.0;
    }

    // PDF file is EATEN (disappears upon bite: 1.5 to 1.7s)
    final double pdfScale;
    final double pdfOpacity;
    if (clampedT < 1.5) {
      pdfScale = 1.0;
      pdfOpacity = 1.0;
    } else if (clampedT <= 1.7) {
      final pEat = _clamp01((clampedT - 1.5) / 0.20);
      pdfScale = 1.0 - pEat;
      pdfOpacity = 1.0 - pEat;
    } else {
      pdfScale = 0.0;
      pdfOpacity = 0.0;
    }

    // 4. Wordmark reveals as crocodile moves rightward (1.8 to 2.6s)
    final double revealProgress = _clamp01((clampedT - 1.8) / 0.7);

    // 5. Scene cross-fade out (2.9 to 3.2s)
    final double sceneOpacity;
    if (clampedT < 2.9) {
      sceneOpacity = 1.0;
    } else if (clampedT >= 3.2) {
      sceneOpacity = 0.0;
    } else {
      sceneOpacity = (1.0 - _clamp01((clampedT - 2.9) / 0.3)).clamp(0.0, 1.0);
    }

    return LaunchTimelineState(
      t: clampedT,
      paperY: paperY,
      paperOpacity: paperOpacity,
      fold: fold,
      textLinesOpacity: textLinesOpacity,
      pdfBadgeOpacity: pdfBadgeOpacity,
      crocX: crocX,
      crocScale: crocScale,
      mouthA: mouthA,
      pdfScale: pdfScale,
      pdfOpacity: pdfOpacity,
      revealProgress: revealProgress,
      sceneOpacity: sceneOpacity,
    );
  }
}

/// Brand colors that follow the system's light/dark mode (D-003).
class _LaunchColors {
  static Color background(bool isDark) =>
      isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  static Color text(bool isDark) =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111111);
  static Color subtext(bool isDark) =>
      isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575);
  static String logoAsset(bool isDark) =>
      isDark ? 'assets/splash/logo_dark.png' : 'assets/splash/logo.png';
}

/// Branded launch animation screen driven by a wall-clock synchronized Ticker.
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
    with TickerProviderStateMixin {
  late AnimationController _controller;
  Ticker? _ticker;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _watchdogTimer;
  Timer? _reducedMotionTimer;
  bool _isFinished = false;
  bool _isReducedMotion = false;
  bool _hasStarted = false;

  bool get _isTestEnvironment =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();

    try {
      if (widget.debugT == null) {
        // 5s watchdog safety net
        _watchdogTimer = Timer(const Duration(milliseconds: 5000), () => _finish('watchdog'));
      }

      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3200),
      );

      int lastLogged = 0;
      _controller.addListener(() {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastLogged > 400 || _controller.value >= 1.0) {
          lastLogged = now;
          debugPrint('[LaunchTiming] TICK v=${_controller.value.toStringAsFixed(3)} at $now');
        }
      });

      _ticker = createTicker((Duration elapsed) {
        if (_isFinished) return;

        final double currentSeconds;
        if (_isTestEnvironment) {
          currentSeconds = (elapsed.inMicroseconds / 1000000.0).clamp(0.0, 3.2);
        } else {
          currentSeconds = (_stopwatch.elapsedMicroseconds / 1000000.0).clamp(0.0, 3.2);
        }

        final progress = (currentSeconds / 3.2).clamp(0.0, 1.0);
        _controller.value = progress;

        if (progress >= 1.0 || currentSeconds >= 3.2) {
          _ticker?.stop();
          _finish('controller_completed');
        }
      });

      if (widget.debugT != null) {
        _controller.value = (widget.debugT! / 3.2).clamp(0.0, 1.0);
      }
    } catch (e, stack) {
      debugPrint('[LaunchTiming] EXCEPTION in initState: $e\n$stack');
      _finish('init_exception');
    }
  }

  @override
  void didUpdateWidget(LaunchAnimationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.debugT != null) {
      if (_ticker?.isTicking ?? false) _ticker?.stop();
      _controller.value = (widget.debugT! / 3.2).clamp(0.0, 1.0);
      _watchdogTimer?.cancel();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    precacheImage(AssetImage(_LaunchColors.logoAsset(isDark)), context);

    final disableAnimations = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.debugT != null) {
      if (_ticker?.isTicking ?? false) _ticker?.stop();
      _controller.value = (widget.debugT! / 3.2).clamp(0.0, 1.0);
      _watchdogTimer?.cancel();
    } else if (disableAnimations && !_isReducedMotion) {
      _isReducedMotion = true;
      if (_ticker?.isTicking ?? false) _ticker?.stop();
      _reducedMotionTimer?.cancel();
      _reducedMotionTimer = Timer(const Duration(milliseconds: 800), () => _finish('reduced_motion'));
    } else if (!_isReducedMotion && !_hasStarted && widget.debugT == null) {
      _hasStarted = true;
      debugPrint('[LaunchTiming] ANIMATION_STARTED (controller.value=${_controller.value}, debugT=${widget.debugT}) at ${DateTime.now().millisecondsSinceEpoch}');
      _stopwatch.start();
      _ticker?.start();
    }
  }

  void _finish([String reason = 'unknown']) {
    if (_isFinished) return;
    _isFinished = true;
    _stopwatch.stop();
    if (_ticker?.isTicking ?? false) {
      _ticker?.stop();
    }
    debugPrint('[LaunchTiming] ANIMATION_FINISHED ($reason) at ${DateTime.now().millisecondsSinceEpoch}');
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
    if (_ticker?.isTicking ?? false) {
      _ticker?.stop();
    }
    _ticker?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = _LaunchColors.background(isDark);
    final logoAsset = _LaunchColors.logoAsset(isDark);
    final textColor = _LaunchColors.text(isDark);
    final subtextColor = _LaunchColors.subtext(isDark);

    // Reduced motion view
    if (_isReducedMotion) {
      return Material(
        type: MaterialType.transparency,
        child: Container(
          color: bgColor,
          child: Center(
            child: _ReducedMotionLogo(isDark: isDark),
          ),
        ),
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = widget.debugT ?? (_controller.value * 3.2);
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
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // 1. PDF Document Icon in middle of screen (Drops, folds, gets eaten)
                      if (state.pdfOpacity > 0.01)
                        Transform.translate(
                          offset: Offset(0, state.paperY),
                          child: Opacity(
                            opacity: (state.paperOpacity * state.pdfOpacity).clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: state.pdfScale,
                              child: PaperDocumentWidget(
                                fold: state.fold,
                                textLinesOpacity: state.textLinesOpacity,
                                pdfBadgeOpacity: state.pdfBadgeOpacity,
                                isDark: isDark,
                              ),
                            ),
                          ),
                        ),

                      // 2. Wordmark centered in middle of screen, revealed as croc moves right
                      if (state.revealProgress > 0.01)
                        ClipRect(
                          clipper: _WordmarkRevealClipper(state.revealProgress * 260.0),
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
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // 3. Crocodile entering from left, eating the file, and moving rightward
                      Transform.translate(
                        offset: Offset(state.crocX, 0.0),
                        child: Transform.scale(
                          scale: state.crocScale,
                          origin: const Offset(42.14, 81.48), // Hinge origin
                          child: SizedBox(
                            width: 140,
                            height: 140,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Solid Upper Head
                                ClipPath(
                                  clipper: const _UpperHeadClipper(),
                                  child: Image.asset(
                                    logoAsset,
                                    width: 140,
                                    height: 140,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) => _finish('upper_asset_error'));
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),

                                // Articulating Lower Jaw
                                Transform.rotate(
                                  angle: 22.0 * (math.pi / 180.0) * state.mouthA,
                                  origin: const Offset(42.14, 81.48),
                                  child: ClipPath(
                                    clipper: const _LowerJawClipper(),
                                    child: Image.asset(
                                      logoAsset,
                                      width: 140,
                                      height: 140,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) => _finish('lower_asset_error'));
                                        return const SizedBox.shrink();
                                      },
                                    ),
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
    );
  }
}

class _ReducedMotionLogo extends StatelessWidget {
  final bool isDark;

  const _ReducedMotionLogo({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final logoAsset = _LaunchColors.logoAsset(isDark);
    final textColor = _LaunchColors.text(isDark);
    final subtextColor = _LaunchColors.subtext(isDark);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          logoAsset,
          width: 90,
          height: 90,
          errorBuilder: (context, error, stackTrace) {
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
    );
  }
}

/// Cuts the solid, unified upper head (skull, 3 crests, eye, upper snout, and top teeth).
class _UpperHeadClipper extends CustomClipper<Path> {
  const _UpperHeadClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    final sx = size.width / 200.0;
    final sy = size.height / 200.0;

    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, 105.0 * sy);
    path.lineTo(120.0 * sx, 105.0 * sy);
    path.lineTo(80.0 * sx, 104.5 * sy);
    path.lineTo(60.2 * sx, 116.4 * sy);
    path.lineTo(60.2 * sx, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Cuts the articulating lower jaw and bottom teeth along the exact mouth cleft.
class _LowerJawClipper extends CustomClipper<Path> {
  const _LowerJawClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    final sx = size.width / 200.0;
    final sy = size.height / 200.0;

    path.moveTo(60.2 * sx, size.height);
    path.lineTo(60.2 * sx, 116.4 * sy);
    path.lineTo(80.0 * sx, 104.5 * sy);
    path.lineTo(120.0 * sx, 105.0 * sy);
    path.lineTo(size.width, 105.0 * sy);
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _LowerJawClipper oldClipper) => false;
}

/// Reveals the wordmark from left to right as the crocodile exits to the right.
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
