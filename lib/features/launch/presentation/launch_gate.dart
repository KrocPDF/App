import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'launch_animation_screen.dart';

/// Gate widget that sits above the app router.
/// Ensures the branded launch animation sequence plays strictly once
/// on process cold-start, while leaving routing, deep links, and warm
/// resumes completely unaffected.
class LaunchGate extends StatefulWidget {
  final Widget child;

  const LaunchGate({super.key, required this.child});

  /// In-memory process flag. Defaults to false on process creation.
  static bool hasCompletedLaunch = false;

  /// Optional debug time override for tests
  static double? debugT;

  /// Test-only reset to simulate a cold start in tests.
  @visibleForTesting
  static void resetColdStartFlagForTesting() {
    hasCompletedLaunch = false;
    debugT = null;
  }

  @override
  State<LaunchGate> createState() => _LaunchGateState();
}

class _LaunchGateState extends State<LaunchGate> {
  static const _channel = MethodChannel('com.krocpdf.app/launch_params');
  late bool _showLaunchScreen;
  double? _intentDebugT;

  @override
  void initState() {
    super.initState();
    _showLaunchScreen = !LaunchGate.hasCompletedLaunch;
    _fetchIntentDebugT();
  }

  Future<void> _fetchIntentDebugT() async {
    try {
      final t = await _channel.invokeMethod<double>('getDebugT');
      if (t != null && mounted) {
        setState(() {
          _intentDebugT = t;
          _showLaunchScreen = true;
        });
      }
    } catch (_) {}
  }

  void _onLaunchComplete() {
    if (!mounted) return;
    LaunchGate.hasCompletedLaunch = true;
    setState(() {
      _showLaunchScreen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_showLaunchScreen) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Router / Home is mounted underneath
        widget.child,
        // Launch animation overlay
        LaunchAnimationScreen(
          onComplete: _onLaunchComplete,
          debugT: _intentDebugT ?? LaunchGate.debugT,
        ),
      ],
    );
  }
}
