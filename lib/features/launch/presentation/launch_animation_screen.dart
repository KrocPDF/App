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
/// Sequence:
/// 1. Paper drops in middle of screen clearly visible with realistic gravity (0.0 - 1.2s)
/// 2. Converts into PDF file (corner folds, lines appear, PDF badge stamps on) (1.2 - 2.0s)
/// 3. Crocodile comes from left, mouth opens wide framing the document (2.0 - 2.7s)
/// 4. Crocodile crunches the PDF file (jaws snap shut, PDF squashes & disappears) (2.7 - 3.0s)
/// 5. Crocodile moves rightward off-screen; wordmark "KrocPDF" reveals in its trail (3.0 - 3.8s)
/// 6. Wordmark holds and cross-fades into Home (3.8 - 4.2s)
class LaunchTimelineState {
  final double t;
  final double paperX;
  final double paperY;
  final double paperOpacity;
  final double fold;
  final double textLinesOpacity;
  final double pdfBadgeOpacity;
  final double crocX;
  final double crocScale;
  final double mouthA;
  final double pdfScale;
  final double pdfScaleX;
  final double pdfScaleY;
  final double pdfOpacity;
  final double revealProgress;
  final double wordmarkOpacity;
  final double sceneOpacity;

  const LaunchTimelineState({
    required this.t,
    required this.paperX,
    required this.paperY,
    required this.paperOpacity,
    required this.fold,
    required this.textLinesOpacity,
    required this.pdfBadgeOpacity,
    required this.crocX,
    required this.crocScale,
    required this.mouthA,
    required this.pdfScale,
    required this.pdfScaleX,
    required this.pdfScaleY,
    required this.pdfOpacity,
    required this.revealProgress,
    required this.wordmarkOpacity,
    required this.sceneOpacity,
  });

  static const easeOutBackCurve = EaseOutBackCurve();
  static const easeOutCubicCurve = EaseOutCubicCurve();
  static const easeInOutQuadCurve = EaseInOutQuadCurve();

  static double _clamp01(double v) => v.clamp(0.0, 1.0);
  static double _lerp(double a, double b, double p) => a + (b - a) * p;

  factory LaunchTimelineState.compute(double t) {
    final clampedT = t.clamp(0.0, 4.2);

    // 1. Paper drops in from top to middle — smooth gravity settle (0.0 - 1.2s)
    final double pDrop = _clamp01(clampedT / 1.15);
    final double paperY = _lerp(-320.0, 0.0, easeOutBackCurve.transform(pDrop));
    final double paperOpacity = _clamp01(clampedT / 0.30);

    // 2. Corner folds into PDF document, lines appear, PDF badge stamps on (1.2 - 2.0s)
    final double pFold = _clamp01((clampedT - 1.2) / 0.45);
    final double fold = pFold * 18.0;
    final double textLinesOpacity = _clamp01((clampedT - 1.30) / 0.35) * 0.9;
    final double pdfBadgeOpacity = _clamp01((clampedT - 1.45) / 0.35);

    // 3. Crocodile enters from off-screen left (-320px) to mouth framing paper (-18px) (2.0 - 2.7s)
    final double crocX;
    if (clampedT < 2.0) {
      crocX = -320.0;
    } else if (clampedT <= 2.7) {
      final pEnter = _clamp01((clampedT - 2.0) / 0.7);
      crocX = _lerp(-320.0, -18.0, easeOutCubicCurve.transform(pEnter));
    } else if (clampedT <= 2.85) {
      // Forward lunge on bite crunch
      final pLunge = _clamp01((clampedT - 2.7) / 0.15);
      crocX = _lerp(-18.0, -8.0, pLunge);
    } else if (clampedT <= 3.15) {
      // Chewing settle before exit
      crocX = -8.0;
    } else if (clampedT <= 3.85) {
      // Moves rightward off-screen
      final pExit = _clamp01((clampedT - 3.15) / 0.7);
      crocX = _lerp(-8.0, 420.0, easeInOutQuadCurve.transform(pExit));
    } else {
      crocX = 420.0;
    }

    // Mouth Opening parameter A (0.0 to 1.0)
    final double mouthA;
    if (clampedT < 2.05) {
      mouthA = 0.0;
    } else if (clampedT <= 2.65) {
      // Opens wide as it approaches the PDF
      mouthA = easeOutCubicCurve.transform(_clamp01((clampedT - 2.05) / 0.60));
    } else if (clampedT <= 2.7) {
      mouthA = 1.0;
    } else if (clampedT <= 2.85) {
      // Snaps shut on crunch
      final pSnap = _clamp01((clampedT - 2.7) / 0.15);
      mouthA = 1.0 - (pSnap * pSnap);
    } else if (clampedT <= 3.15) {
      // Chewing motion
      final pChew = _clamp01((clampedT - 2.85) / 0.3);
      mouthA = 0.18 * math.sin(pChew * 2 * math.pi).abs() * (1.0 - pChew);
    } else {
      mouthA = 0.0;
    }

    // Scale pulse on bite crunch
    final double crocScale;
    if (clampedT >= 2.7 && clampedT <= 2.95) {
      final pPulse = _clamp01((clampedT - 2.7) / 0.25);
      crocScale = 1.0 + 0.10 * math.sin(pPulse * math.pi);
    } else {
      crocScale = 1.0;
    }

    // 4. PDF file: Clamped by croc's jaws on bite and CARRIED WITH IT off-screen
    final double paperX;
    final double actualPaperY;
    final double pdfScaleX;
    final double pdfScaleY;
    final double pdfOpacity;

    if (clampedT < 2.7) {
      paperX = 0.0;
      actualPaperY = paperY;
      pdfScaleX = 1.0;
      pdfScaleY = 1.0;
      pdfOpacity = 1.0;
    } else if (clampedT <= 3.85) {
      // Croc bites and carries the PDF with it!
      final pClamp = _clamp01((clampedT - 2.7) / 0.15);
      paperX = _lerp(0.0, crocX + 18.0, pClamp);
      actualPaperY = _lerp(paperY, -4.0, pClamp);
      // Bitten / squashed slightly by the jaws as it's carried:
      pdfScaleX = _lerp(1.0, 0.88, pClamp);
      pdfScaleY = _lerp(1.0, 0.80, pClamp);
      pdfOpacity = 1.0;
    } else {
      // Carried completely off-screen
      paperX = crocX + 18.0;
      actualPaperY = -4.0;
      pdfScaleX = 0.0;
      pdfScaleY = 0.0;
      pdfOpacity = 0.0;
    }
    final double pdfScale = pdfScaleY;

    // 5. Wordmark "KrocPDF": Uncovers smoothly as the crocodile moves rightward
    final double revealProgress;
    final double wordmarkOpacity;
    if (clampedT < 3.15) {
      revealProgress = 0.0;
      wordmarkOpacity = 0.0;
    } else {
      revealProgress = _clamp01((clampedT - 3.20) / 0.55);
      wordmarkOpacity = _clamp01((clampedT - 3.20) / 0.25);
    }

    // 6. Scene cross-fade out (4.0 to 4.2s)
    final double sceneOpacity;
    if (clampedT < 4.0) {
      sceneOpacity = 1.0;
    } else if (clampedT >= 4.2) {
      sceneOpacity = 0.0;
    } else {
      sceneOpacity = (1.0 - _clamp01((clampedT - 4.0) / 0.2)).clamp(0.0, 1.0);
    }

    return LaunchTimelineState(
      t: clampedT,
      paperX: paperX,
      paperY: actualPaperY,
      paperOpacity: paperOpacity,
      fold: fold,
      textLinesOpacity: textLinesOpacity,
      pdfBadgeOpacity: pdfBadgeOpacity,
      crocX: crocX,
      crocScale: crocScale,
      mouthA: mouthA,
      pdfScale: pdfScale,
      pdfScaleX: pdfScaleX,
      pdfScaleY: pdfScaleY,
      pdfOpacity: pdfOpacity,
      revealProgress: revealProgress,
      wordmarkOpacity: wordmarkOpacity,
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
  static const double _totalDuration = 4.2;

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
        _watchdogTimer = Timer(
          const Duration(milliseconds: 6000),
          () => _finish('watchdog'),
        );
      }

      _controller = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: (_totalDuration * 1000).round()),
      );

      _ticker = createTicker((Duration elapsed) {
        if (_isFinished) return;

        final double currentSeconds;
        if (_isTestEnvironment) {
          currentSeconds = (elapsed.inMicroseconds / 1000000.0).clamp(
            0.0,
            _totalDuration,
          );
        } else {
          currentSeconds = (_stopwatch.elapsedMicroseconds / 1000000.0).clamp(
            0.0,
            _totalDuration,
          );
        }

        final progress = (currentSeconds / _totalDuration).clamp(0.0, 1.0);
        _controller.value = progress;

        if (progress >= 1.0 || currentSeconds >= _totalDuration) {
          _ticker?.stop();
          _finish('controller_completed');
        }
      });

      if (widget.debugT != null) {
        _controller.value = (widget.debugT! / _totalDuration).clamp(0.0, 1.0);
      }
    } catch (_) {
      _finish('init_exception');
    }
  }

  @override
  void didUpdateWidget(LaunchAnimationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.debugT != null) {
      if (_ticker?.isTicking ?? false) _ticker?.stop();
      _controller.value = (widget.debugT! / _totalDuration).clamp(0.0, 1.0);
      _watchdogTimer?.cancel();
    } else if (oldWidget.debugT != null && !_isFinished && !_isReducedMotion) {
      _hasStarted = true;
      _stopwatch
        ..reset()
        ..start();
      if (!(_ticker?.isTicking ?? false)) {
        _ticker?.start();
      }
      _watchdogTimer?.cancel();
      _watchdogTimer = Timer(
        const Duration(milliseconds: 6000),
        () => _finish('watchdog'),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    precacheImage(AssetImage(_LaunchColors.logoAsset(isDark)), context);

    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.debugT != null) {
      if (_ticker?.isTicking ?? false) _ticker?.stop();
      _controller.value = (widget.debugT! / _totalDuration).clamp(0.0, 1.0);
      _watchdogTimer?.cancel();
    } else if (disableAnimations && !_isReducedMotion) {
      _isReducedMotion = true;
      if (_ticker?.isTicking ?? false) _ticker?.stop();
      _reducedMotionTimer?.cancel();
      _reducedMotionTimer = Timer(
        const Duration(milliseconds: 800),
        () => _finish('reduced_motion'),
      );
    } else if (!_isReducedMotion && !_hasStarted && widget.debugT == null) {
      _hasStarted = true;
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

    if (_isReducedMotion) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.debugT == null ? () => _finish('tap_skip') : null,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            color: bgColor,
            child: Center(child: _ReducedMotionLogo(isDark: isDark)),
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.debugT == null ? () => _finish('tap_skip') : null,
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = widget.debugT ?? (_controller.value * _totalDuration);
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
                        // 1. PDF Document Icon in middle of screen (Drops, folds, gets carried away in croc's jaws)
                        if (state.pdfOpacity > 0.001)
                          Transform.translate(
                            offset: Offset(state.paperX, state.paperY),
                            child: Opacity(
                              opacity: (state.paperOpacity * state.pdfOpacity)
                                  .clamp(0.0, 1.0),
                              child: Transform.scale(
                                scaleX: state.pdfScaleX,
                                scaleY: state.pdfScaleY,
                                origin: const Offset(31.0, 40.0),
                                child: PaperDocumentWidget(
                                  fold: state.fold,
                                  textLinesOpacity: state.textLinesOpacity,
                                  pdfBadgeOpacity: state.pdfBadgeOpacity,
                                  isDark: isDark,
                                ),
                              ),
                            ),
                          ),

                        // 2. Wordmark — Revealed smoothly as crocodile moves rightward
                        if (state.revealProgress > 0.001)
                          Transform.translate(
                            offset: const Offset(0, 0.0),
                            child: Opacity(
                              opacity: state.wordmarkOpacity.clamp(0.0, 1.0),
                              child: ClipRect(
                                clipper: _WordmarkRevealClipper(
                                  state.revealProgress * 260.0,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'KrocPDF',
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 34,
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
                            ),
                          ),

                        // 3. Crocodile entering from left, eating the file, and moving rightward
                        Transform.translate(
                          offset: Offset(state.crocX, -4.0),
                          child: Transform.scale(
                            scale: state.crocScale,
                            origin: const Offset(80.0, 80.0),
                            child: SizedBox(
                              width: 160,
                              height: 160,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // Solid Upper Head and Body (Keeps body & neck 100% intact)
                                  ClipPath(
                                    clipper: const _UpperHeadClipper(),
                                    child: Image.asset(
                                      logoAsset,
                                      width: 160,
                                      height: 160,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            WidgetsBinding.instance
                                                .addPostFrameCallback(
                                                  (_) => _finish(
                                                    'upper_asset_error',
                                                  ),
                                                );
                                            return const SizedBox.shrink();
                                          },
                                    ),
                                  ),

                                  // Articulating Lower Jaw (Articulates around true mouth cleft hinge)
                                  Transform.rotate(
                                    angle:
                                        14.0 * (math.pi / 180.0) * state.mouthA,
                                    alignment: Alignment.topLeft,
                                    origin: const Offset(
                                      160.0 * 190.0 / 512.0,
                                      160.0 * 270.0 / 512.0,
                                    ),
                                    child: ClipPath(
                                      clipper: const _LowerJawClipper(),
                                      child: Image.asset(
                                        logoAsset,
                                        width: 160,
                                        height: 160,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback(
                                                    (_) => _finish(
                                                      'lower_asset_error',
                                                    ),
                                                  );
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

/// Cuts the solid, unified upper head and full body/neck.
/// Preserves the entire neck and skull intact without any broken gaps.
class _UpperHeadClipper extends CustomClipper<Path> {
  const _UpperHeadClipper();

  static const double _seamOverlap = 1.5;

  @override
  Path getClip(Size size) {
    final pivotX = size.width * (190.0 / 512.0);
    final pivotY = size.height * (270.0 / 512.0);

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, pivotY + _seamOverlap);
    path.lineTo(pivotX, pivotY + _seamOverlap);
    path.lineTo(pivotX, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Cuts the articulating lower jaw and bottom teeth along the exact mouth cleft.
/// Rotates around the true mouth hinge point without cutting into the neck.
class _LowerJawClipper extends CustomClipper<Path> {
  const _LowerJawClipper();

  static const double _seamOverlap = 1.5;

  @override
  Path getClip(Size size) {
    final pivotX = size.width * (190.0 / 512.0);
    final pivotY = size.height * (270.0 / 512.0);

    final path = Path();
    path.moveTo(pivotX, pivotY - _seamOverlap);
    path.lineTo(size.width, pivotY - _seamOverlap);
    path.lineTo(size.width, size.height);
    path.lineTo(pivotX, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _LowerJawClipper oldClipper) => false;
}

/// Reveals the wordmark from left to right.
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
