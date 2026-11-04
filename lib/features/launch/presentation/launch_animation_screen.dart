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

/// Computes the exact mathematical state of the launch sequence at second [t] (0.0 to 4.2s).
/// Every value is a pure function of t.
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
  final double iconRotate;
  final double iconScale;
  final double iconXOffset;
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
    required this.iconRotate,
    required this.iconScale,
    required this.iconXOffset,
    required this.revealProgress,
    required this.sceneOpacity,
  });

  static const easeOutBackCurve = EaseOutBackCurve();
  static const easeOutCubicCurve = EaseOutCubicCurve();
  static const easeInOutQuadCurve = EaseInOutQuadCurve();

  static double _clamp01(double v) => v.clamp(0.0, 1.0);
  static double _lerp(double a, double b, double p) => a + (b - a) * p;

  factory LaunchTimelineState.compute(double t) {
    final clampedT = t.clamp(0.0, 4.2);

    // 0 to 0.8s: Paper drops in from top with easeOutBack
    final double paperY = _lerp(-200.0, 0.0, easeOutBackCurve.transform(_clamp01(clampedT / 0.8)));
    final double paperOpacity = _clamp01(clampedT / 0.2);

    // 0.8 to 1.4s: Corner dog-ear folds to 18px
    final double fold = _clamp01((clampedT - 0.8) / 0.6) * 18.0;

    // 0.9 to 1.3s: Text lines fade in
    final double textLinesOpacity = _clamp01((clampedT - 0.9) / 0.4) * 0.9;

    // 1.0 to 1.4s: "PDF" badge fades in
    final double pdfBadgeOpacity = _clamp01((clampedT - 1.0) / 0.4);

    // Crocodile X translation:
    // 1.0 to 1.6s: enters from -230 to -30
    // 1.6 to 1.85s: lunges forward to center (0.0)
    // 1.85 to 3.1s: exits right off-screen (0 to 420)
    final double crocX;
    if (clampedT < 1.0) {
      crocX = -230.0;
    } else if (clampedT <= 1.6) {
      crocX = _lerp(-230.0, -30.0, easeOutCubicCurve.transform(_clamp01((clampedT - 1.0) / 0.6)));
    } else if (clampedT <= 1.85) {
      crocX = _lerp(-30.0, 0.0, _clamp01((clampedT - 1.6) / 0.25));
    } else if (clampedT <= 3.1) {
      crocX = _lerp(0.0, 420.0, easeInOutQuadCurve.transform(_clamp01((clampedT - 1.85) / 1.25)));
    } else {
      crocX = 420.0;
    }

    // Crocodile scale pulse on bite (1.6 to 1.95s)
    final double crocScale;
    if (clampedT >= 1.6 && clampedT <= 1.95) {
      crocScale = 1.0 + 0.06 * math.sin(_clamp01((clampedT - 1.6) / 0.35) * math.pi);
    } else {
      crocScale = 1.0;
    }

    // Mouth Opening parameter A (0.0 = closed, 1.0 = open):
    // 1.0 to 1.62s: mouth opens (reaches 1.0 at 1.45s and holds until 1.62s)
    // 1.62 to 1.85s: jaws clamp shut to 0 by 1.85s
    // 1.85 to 2.2s: subtle chewing settle
    final double mouthA;
    if (clampedT < 1.0) {
      mouthA = 0.0;
    } else if (clampedT <= 1.62) {
      mouthA = easeOutCubicCurve.transform(_clamp01((clampedT - 1.0) / 0.45));
    } else if (clampedT <= 1.85) {
      mouthA = 1.0 - easeOutCubicCurve.transform(_clamp01((clampedT - 1.62) / 0.23));
    } else if (clampedT <= 2.2) {
      final chewP = _clamp01((clampedT - 1.85) / 0.35);
      mouthA = 0.22 * math.sin(chewP * 2 * math.pi) * (1.0 - chewP);
    } else {
      mouthA = 0.0;
    }

    // PDF Icon reacts when bitten (1.65 to 1.85s):
    // rotates -10 deg, scales down to 0.85, shifts left -12px
    final double iconRotate;
    final double iconScale;
    final double iconXOffset;
    if (clampedT < 1.65) {
      iconRotate = 0.0;
      iconScale = 1.0;
      iconXOffset = 0.0;
    } else if (clampedT <= 1.85) {
      final p = _clamp01((clampedT - 1.65) / 0.20);
      iconRotate = -10.0 * (math.pi / 180.0) * p;
      iconScale = 1.0 - 0.15 * p;
      iconXOffset = -12.0 * p;
    } else {
      iconRotate = -10.0 * (math.pi / 180.0);
      iconScale = 0.85;
      iconXOffset = -12.0;
    }

    // Wordmark reveals from left-to-right behind exiting crocodile (1.85 to 2.85s)
    final double revealProgress = _clamp01((clampedT - 1.85) / 1.0);

    // Scene cross-fade out (3.8 to 4.2s)
    final double sceneOpacity;
    if (clampedT < 3.8) {
      sceneOpacity = 1.0;
    } else if (clampedT >= 4.2) {
      sceneOpacity = 0.0;
    } else {
      sceneOpacity = (1.0 - _clamp01((clampedT - 3.8) / 0.4)).clamp(0.0, 1.0);
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
      iconRotate: iconRotate,
      iconScale: iconScale,
      iconXOffset: iconXOffset,
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
        // 6s watchdog safety net
        _watchdogTimer = Timer(const Duration(milliseconds: 6000), () => _finish('watchdog'));
      }

      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 4200),
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
          currentSeconds = (elapsed.inMicroseconds / 1000000.0).clamp(0.0, 4.2);
        } else {
          currentSeconds = (_stopwatch.elapsedMicroseconds / 1000000.0).clamp(0.0, 4.2);
        }

        final progress = (currentSeconds / 4.2).clamp(0.0, 1.0);
        _controller.value = progress;

        if (progress >= 1.0 || currentSeconds >= 4.2) {
          _ticker?.stop();
          _finish('controller_completed');
        }
      });

      if (widget.debugT != null) {
        _controller.value = (widget.debugT! / 4.2).clamp(0.0, 1.0);
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
      _controller.value = (widget.debugT! / 4.2).clamp(0.0, 1.0);
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
      _controller.value = (widget.debugT! / 4.2).clamp(0.0, 1.0);
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
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // 1. PDF Document Icon (Drops in center, folds, gets bitten and tilts)
                      Opacity(
                        opacity: state.paperOpacity.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(state.iconXOffset, state.paperY),
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
                      ),

                      // 2. Crocodile (Enters from left, mouth opens, lunges, clamps & exits right)
                      Transform.translate(
                        offset: Offset(state.crocX, 0.0),
                        child: Transform.scale(
                          scale: state.crocScale,
                          origin: const Offset(42.14, 81.48), // (60.2 * 140/200, 116.4 * 140/200)
                          child: SizedBox(
                            width: 140,
                            height: 140,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Solid, unified Upper Head (cranium, crests, snout, upper teeth)
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

                                // Articulating Lower Jaw (mandible, lower teeth)
                                Transform.rotate(
                                  angle: 18.0 * (math.pi / 180.0) * state.mouthA,
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

                      // 3. Wordmark revealed from left-to-right behind exiting crocodile
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
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 5),
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
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
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
