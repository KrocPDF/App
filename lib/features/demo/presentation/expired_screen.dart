import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen lock shown once the expo demo has expired.
/// Blocks Back navigation via [PopScope] and offers direct uninstall via Android's
/// standard system confirmation dialog (`Intent.ACTION_DELETE`).
class ExpiredScreen extends StatefulWidget {
  const ExpiredScreen({super.key});

  @override
  State<ExpiredScreen> createState() => _ExpiredScreenState();
}

class _ExpiredScreenState extends State<ExpiredScreen> {
  static const MethodChannel _uninstallChannel = MethodChannel(
    'com.krocpdf.app/demo_uninstall',
  );

  bool _isLaunchingUninstall = false;

  Future<void> _handleUninstall() async {
    if (_isLaunchingUninstall) {
      return;
    }
    setState(() => _isLaunchingUninstall = true);
    try {
      await _uninstallChannel.invokeMethod<bool>('uninstallApp');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open uninstall prompt: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLaunchingUninstall = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E1E1E)
                            : const Color(0xFFF2F2F2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.outline,
                          width: 1,
                        ),
                      ),
                      child: const Icon(Icons.timer_off_outlined, size: 34),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Demo expired. Thanks for trying!\nAll your data has been deleted.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This expo preview build is no longer active. Please uninstall the app from your device.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLaunchingUninstall
                            ? null
                            : _handleUninstall,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: Text(
                          _isLaunchingUninstall
                              ? 'Opening uninstall...'
                              : 'Uninstall now',
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
