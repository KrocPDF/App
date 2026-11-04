import 'dart:async';
import 'package:flutter/material.dart';
import 'paper_document_widget.dart';

/// Full-screen branded launch animation sequence:
/// 1. Paper drops in from top (~0.0s - 0.7s)
/// 2. Paper folds into PDF icon (~0.7s - 1.3s)
/// 3. KrocPDF crocodile enters from left and "eats" the PDF icon (~1.3s - 2.1s)
/// 4. Crocodile settles, KrocPDF wordmark reveals & holds (~2.1s - 2.7s)
/// 5. Smooth cross-fade to Home screen (~2.7s - 3.0s)
class LaunchAnimationScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const LaunchAnimationScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<LaunchAnimationScreen> createState() => _LaunchAnimationScreenState();
}

class _LaunchAnimationScreenState extends State<LaunchAnimationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Staged interval animations
  late Animation<double> _paperDropY;
  late Animation<double> _paperOpacity;
  late Animation<double> _paperFold;

  late Animation<double> _crocSlideX;
  late Animation<double> _crocOpacity;
  late Animation<double> _crocLungeScale;

  late Animation<double> _pdfShrinkScale;
  late Animation<double> _pdfShrinkOpacity;

  late Animation<double> _crocCenterY;
  late Animation<double> _wordmarkOpacity;
  late Animation<double> _wordmarkSlideY;

  late Animation<double> _screenFadeOut;

  Timer? _watchdogTimer;
  Timer? _reducedMotionTimer;
  bool _isFinished = false;
  bool _isReducedMotion = false;

  @override
  void initState() {
    super.initState();

    try {
      // 5-second watchdog safety net: guarantees navigation even if animation freezes
      _watchdogTimer = Timer(const Duration(milliseconds: 5000), () {
        _finish();
      });

      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3000),
      );

      // Stage 1: Paper drops in from top (0.00 -> 0.23: 0ms - 700ms)
      _paperDropY = Tween<double>(begin: -320.0, end: 0.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.00, 0.23, curve: Curves.easeOutBack),
        ),
      );
      _paperOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.00, 0.08, curve: Curves.easeIn),
        ),
      );

      // Stage 2: Paper folds into PDF document icon (0.23 -> 0.43: 700ms - 1300ms)
      _paperFold = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.23, 0.43, curve: Curves.easeInOutCubic),
        ),
      );

      // Stage 3: Crocodile enters from left (0.43 -> 0.70: 1300ms - 2100ms)
      _crocSlideX = Tween<double>(begin: -280.0, end: 0.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.43, 0.65, curve: Curves.easeOutCubic),
        ),
      );
      _crocOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.43, 0.52, curve: Curves.easeIn),
        ),
      );
      // Crocodile lunge & bite motion
      _crocLungeScale = TweenSequence<double>([
        TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.18).chain(CurveTween(curve: Curves.easeOutQuad)), weight: 50),
        TweenSequenceItem(tween: Tween<double>(begin: 1.18, end: 1.0).chain(CurveTween(curve: Curves.easeInQuad)), weight: 50),
      ]).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.55, 0.67),
        ),
      );

      // PDF icon shrinks & disappears into croc mouth (0.57 -> 0.68)
      _pdfShrinkScale = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.57, 0.68, curve: Curves.easeInBack),
        ),
      );
      _pdfShrinkOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.57, 0.66, curve: Curves.easeIn),
        ),
      );

      // Stage 4: Crocodile shifts up, wordmark reveals & holds (0.70 -> 0.90: 2100ms - 2700ms)
      _crocCenterY = Tween<double>(begin: 0.0, end: -36.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.70, 0.78, curve: Curves.easeOutCubic),
        ),
      );
      _wordmarkOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.72, 0.82, curve: Curves.easeOut),
        ),
      );
      _wordmarkSlideY = Tween<double>(begin: 18.0, end: 0.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.72, 0.82, curve: Curves.easeOutCubic),
        ),
      );

      // Stage 5: Cross-fade entire screen to reveal Home (0.90 -> 1.00: 2700ms - 3000ms)
      _screenFadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.90, 1.00, curve: Curves.easeIn),
        ),
      );

      // Normal navigation fires strictly upon animation completion
      _controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _finish();
        }
      });
    } catch (e) {
      // Any setup failure immediately bails out to Home
      _finish();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isFinished && !_isReducedMotion) {
      // Use only MediaQuery.disableAnimationsOf(context), NOT accessibleNavigation
      final disableAnimations = MediaQuery.disableAnimationsOf(context);
      if (disableAnimations) {
        _isReducedMotion = true;
        // Show static logo & wordmark briefly (600ms), then proceed to Home
        _reducedMotionTimer = Timer(const Duration(milliseconds: 600), () {
          _finish();
        });
      } else {
        if (!_controller.isAnimating && !_controller.isCompleted) {
          _controller.forward();
        }
      }
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
    // Exactly matches native splash background (#FFFFFF light, #000000 dark)
    final bgColor = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final logoAsset = isDark ? 'assets/splash/logo_dark.png' : 'assets/splash/logo.png';
    final textColor = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111111);
    final subtextColor = isDark ? const Color(0xFF9E9E9E) : const Color(0xFF757575);

    // Reduced motion view: static logo + wordmark without motion
    if (_isReducedMotion) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _finish,
        child: Container(
          color: bgColor,
          alignment: Alignment.center,
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
      );
    }

    // Full Animated Sequence
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish, // Tap anywhere skips
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final fadeOut = _screenFadeOut.value;

          return Opacity(
            opacity: fadeOut,
            child: Container(
              color: bgColor,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Paper / PDF Icon (Drops, folds, then gets eaten)
                    if (_pdfShrinkOpacity.value > 0.01)
                      Transform.translate(
                        offset: Offset(0, _paperDropY.value),
                        child: Opacity(
                          opacity: _paperOpacity.value * _pdfShrinkOpacity.value,
                          child: Transform.scale(
                            scale: _pdfShrinkScale.value,
                            child: PaperDocumentWidget(
                              foldProgress: _paperFold.value,
                              isDark: isDark,
                            ),
                          ),
                        ),
                      ),

                    // 2. Crocodile Mark (Enters from left, lunges & eats PDF, centers)
                    if (_crocOpacity.value > 0.01)
                      Transform.translate(
                        offset: Offset(_crocSlideX.value, _crocCenterY.value),
                        child: Opacity(
                          opacity: _crocOpacity.value,
                          child: Transform.scale(
                            scale: _crocLungeScale.value,
                            child: Image.asset(
                              logoAsset,
                              width: 94,
                              height: 94,
                              errorBuilder: (context, error, stackTrace) {
                                // Fail gracefully straight to Home
                                WidgetsBinding.instance.addPostFrameCallback((_) => _finish());
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                      ),

                    // 3. Wordmark & Tagline (Reveals in Stage 4 and holds)
                    if (_wordmarkOpacity.value > 0.01)
                      Transform.translate(
                        offset: Offset(0, 48 + _wordmarkSlideY.value),
                        child: Opacity(
                          opacity: _wordmarkOpacity.value,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'KrocPDF',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Fast. Private. On-device.',
                                style: TextStyle(
                                  color: subtextColor,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
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
          );
        },
      ),
    );
  }
}
