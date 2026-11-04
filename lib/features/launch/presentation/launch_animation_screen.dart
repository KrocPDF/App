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

/// Computes the exact mathematical state of the launch sequence at second [t] (0.0 to 2.8s).
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
  final double pdfScale;
  final double pdfOpacity;
  final double crocY;
  final double wordmarkOpacity;
  final double wordmarkY;
  final double sceneOpacity;
  final int wordmarkCharsShown;
  final double taglineOpacity;

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
    required this.crocY,
    required this.wordmarkOpacity,
    required this.wordmarkY,
    required this.sceneOpacity,
    required this.wordmarkCharsShown,
    required this.taglineOpacity,
  });

  static const easeOutBackCurve = EaseOutBackCurve();
  static const easeOutCubicCurve = EaseOutCubicCurve();

  static const String wordmarkFullText = 'KrocPDF';

  static double _clamp01(double v) => v.clamp(0.0, 1.0);
  static double _lerp(double a, double b, double p) => a + (b - a) * p;

  factory LaunchTimelineState.compute(double t) {
    final clampedT = t.clamp(0.0, 2.8);

    // Stage 1: Paper drops in from top (0.0 to 0.7s)
    final double pDrop = _clamp01(clampedT / 0.7);
    final double paperY = _lerp(-240.0, 0.0, easeOutBackCurve.transform(pDrop));
    final double paperOpacity = _clamp01(clampedT / 0.2);

    // Stage 2: Corner folds into PDF document icon (0.7 to 1.3s)
    final double pFold = _clamp01((clampedT - 0.7) / 0.5);
    final double fold = pFold * 18.0;
    final double textLinesOpacity = _clamp01((clampedT - 0.8) / 0.3) * 0.9;
    final double pdfBadgeOpacity = _clamp01((clampedT - 0.9) / 0.35);

    // Stage 3: Crocodile enters, mouth opens, lunges, and eats the PDF icon (1.2 to 2.1s)
    final double crocX;
    if (clampedT < 1.2) {
      crocX = -240.0;
    } else if (clampedT <= 1.7) {
      crocX = _lerp(-240.0, 0.0, easeOutCubicCurve.transform(_clamp01((clampedT - 1.2) / 0.5)));
    } else {
      crocX = 0.0;
    }

    final double mouthA;
    if (clampedT < 1.2) {
      mouthA = 0.0;
    } else if (clampedT <= 1.75) {
      mouthA = easeOutCubicCurve.transform(_clamp01((clampedT - 1.2) / 0.45));
    } else if (clampedT <= 1.95) {
      final pShut = _clamp01((clampedT - 1.75) / 0.20);
      mouthA = 1.0 - (pShut * pShut);
    } else if (clampedT <= 2.15) {
      final chewT = clampedT - 1.95;
      mouthA = 0.08 * math.sin(chewT * 20.0).abs() * (1.0 - _clamp01(chewT / 0.2));
    } else {
      mouthA = 0.0;
    }

    final double crocScale;
    if (clampedT >= 1.65 && clampedT <= 1.95) {
      final pPulse = _clamp01((clampedT - 1.65) / 0.30);
      crocScale = 1.0 + 0.12 * math.sin(pPulse * math.pi);
    } else {
      crocScale = 1.0;
    }

    final double pdfScale;
    final double pdfOpacity;
    if (clampedT < 1.75) {
      pdfScale = 1.0;
      pdfOpacity = 1.0;
    } else if (clampedT <= 1.95) {
      final pEat = _clamp01((clampedT - 1.75) / 0.20);
      pdfScale = 1.0 - pEat;
      pdfOpacity = 1.0 - pEat;
    } else {
      pdfScale = 0.0;
      pdfOpacity = 0.0;
    }

    // Stage 4: Crocodile shifts up, wordmark types out letter-by-letter, holds, then fades
    final double pShift = _clamp01((clampedT - 2.05) / 0.25);
    final double crocY = _lerp(0.0, -32.0, easeOutCubicCurve.transform(pShift));

    // Wordmark container fade/slide-in (starts the moment typing begins)
    final double pWordmark = _clamp01((clampedT - 2.15) / 0.15);
    final double wordmarkOpacity = pWordmark;
    final double wordmarkY = _lerp(14.0, 0.0, easeOutCubicCurve.transform(pWordmark));

    // Letter-by-letter typewriter reveal: types out "KrocPDF" from 2.15s to 2.55s
    final double pTyping = _clamp01((clampedT - 2.15) / 0.40);
    final int wordmarkCharsShown =
        (pTyping * wordmarkFullText.length).floor().clamp(0, wordmarkFullText.length);

    // Tagline only fades in once the full word has finished typing (2.55 to 2.65s)
    final double taglineOpacity = _clamp01((clampedT - 2.55) / 0.10);

    // Scene cross-fade out (2.65 to 2.80s)
    final double sceneOpacity;
    if (clampedT < 2.65) {
      sceneOpacity = 1.0;
    } else if (clampedT >= 2.80) {
      sceneOpacity = 0.0;
    } else {
      sceneOpacity = (1.0 - _clamp01((clampedT - 2.65) / 0.15)).clamp(0.0, 1.0);
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
      crocY: crocY,
      wordmarkOpacity: wordmarkOpacity,
      wordmarkY: wordmarkY,
      sceneOpacity: sceneOpacity,
      wordmarkCharsShown: wordmarkCharsShown,
      taglineOpacity: taglineOpacity,
    );
  }
}

/// Brand colors that follow the system's light/dark mode, consistent with
/// the rest of the app's theme (D-003). Light mode: white background, black
/// crocodile/text. Dark mode: black background, white crocodile/text.
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
        duration: const Duration(milliseconds: 2800),
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
          currentSeconds = (elapsed.inMicroseconds / 1000000.0).clamp(0.0, 2.8);
        } else {
          currentSeconds = (_stopwatch.elapsedMicroseconds / 1000000.0).clamp(0.0, 2.8);
        }

        final progress = (currentSeconds / 2.8).clamp(0.0, 1.0);
        _controller.value = progress;

        if (progress >= 1.0 || currentSeconds >= 2.8) {
          _ticker?.stop();
          _finish('controller_completed');
        }
      });

      if (widget.debugT != null) {
        _controller.value = (widget.debugT! / 2.8).clamp(0.0, 1.0);
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
      _controller.value = (widget.debugT! / 2.8).clamp(0.0, 1.0);
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
      _controller.value = (widget.debugT! / 2.8).clamp(0.0, 1.0);
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
        child: ColoredBox(
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
          final t = widget.debugT ?? (_controller.value * 2.8);
          final state = LaunchTimelineState.compute(t);
          final displayedWordmark = LaunchTimelineState.wordmarkFullText
              .substring(0, state.wordmarkCharsShown);

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
                      // 1. PDF Document Icon (Drops in center, folds, gets eaten into croc mouth)
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

                      // 2. Crocodile (Enters from left, mouth opens, lunges & eats PDF, shifts up to center)
                      Transform.translate(
                        offset: Offset(state.crocX, state.crocY),
                        child: Transform.scale(
                          scale: state.crocScale,
                          origin: const Offset(42.14, 81.48),
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

                      // 3. Wordmark: types out letter-by-letter, tagline follows once fully typed
                      if (state.wordmarkOpacity > 0.01)
                        Transform.translate(
                          offset: Offset(0, 68.0 + state.wordmarkY),
                          child: Opacity(
                            opacity: state.wordmarkOpacity.clamp(0.0, 1.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 36,
                                  child: Text(
                                    displayedWordmark,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Opacity(
                                  opacity: state.taglineOpacity.clamp(0.0, 1.0),
                                  child: Text(
                                    'Fast. Private. On-device.',
                                    style: TextStyle(
                                      color: subtextColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ],
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          _LaunchColors.logoAsset(isDark),
          width: 90,
          height: 90,
        ),
        const SizedBox(height: 18),
        Text(
          'KrocPDF',
          style: TextStyle(
            color: _LaunchColors.text(isDark),
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Fast. Private. On-device.',
          style: TextStyle(
            color: _LaunchColors.subtext(isDark),
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
/// The skull remains completely intact and rigid throughout the animation, preventing
/// any visual fractures, disconnections, or broken jaw outlines.
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
/// Hinges seamlessly at Offset(42.14, 81.48) at the back vertex of the mouth cavity.
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