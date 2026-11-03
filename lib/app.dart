import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/files/presentation/files_screen.dart';
import 'features/files/presentation/pdf_viewer_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/tool_flow/presentation/document_editor_screen.dart';
import 'features/tool_flow/presentation/tool_detail_screen.dart';
import 'features/tool_flow/presentation/tool_flow_screen.dart';

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/pdf-viewer',
      builder: (context, state) {
        final filePath = state.uri.queryParameters['path'] ?? '';
        final title = state.uri.queryParameters['title'] ?? 'Document';
        return PdfViewerScreen(filePath: filePath, title: title);
      },
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppCoreSkeleton(navigationShell: navigationShell);
      },
      branches: [
        // Branch 0: Home tab with nested tool flows and document editor
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'edit-document',
                  builder: (context, state) => const DocumentEditorScreen(),
                ),
                GoRoute(
                  path: 'tool/:toolId',
                  builder: (context, state) {
                    final toolId = state.pathParameters['toolId'] ?? '';
                    return ToolDetailScreen(toolId: toolId);
                  },
                  routes: [
                    GoRoute(
                      path: 'flow',
                      builder: (context, state) {
                        final toolId = state.pathParameters['toolId'] ?? '';
                        final format = state.uri.queryParameters['format'];
                        final initialFilePath =
                            state.uri.queryParameters['initialFilePath'];
                        return ToolFlowScreen(
                          toolId: toolId,
                          format: format,
                          initialFilePath: initialFilePath,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // Branch 1: Scan tab
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/scan',
              builder: (context, state) => const ScanLandingScreen(),
            ),
          ],
        ),

        // Branch 2: Files tab
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/files',
              builder: (context, state) => const FilesScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

class KrocApp extends StatelessWidget {
  const KrocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KrocPDF',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}

/// Helper to launch camera scanner with graceful error handling
Future<void> launchDocumentScanner(BuildContext context, WidgetRef ref) async {
  try {
    final pictures = await CunningDocumentScanner.getPictures(
      androidScannerMode: AndroidScannerMode.full,
      scannerSource: ScannerSource.camera,
    );
    if (pictures != null && pictures.isNotEmpty && context.mounted) {
      ref.read(documentEditorProvider.notifier).init(pictures);
      context.push('/edit-document');
    }
  } on PlatformException catch (e) {
    if (context.mounted) {
      final isPlayServices =
          e.code.contains('PLAY_SERVICES') ||
          (e.message?.contains('Play Services') == true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPlayServices
                ? 'Document Scanner requires Google Play Services, which is not available on this device. You can use "Image to PDF" to import files.'
                : 'Scanner error: ${e.message ?? e.code}',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Camera scanner unavailable on this device. You can use "Image to PDF" to import files.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }
}

/// Scan landing screen for the Scan branch tab
class ScanLandingScreen extends ConsumerWidget {
  const ScanLandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = theme.colorScheme.outline;

    return Scaffold(
      appBar: AppBar(title: const Text('Document Scanner')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.document_scanner_outlined, size: 36),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Scan Documents',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Capture multi-page paper documents with automatic edge detection and perspective correction.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => launchDocumentScanner(context, ref),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Start Camera Scan'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.push('/edit-document'),
                    child: const Text('Open Page Editor'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Core skeleton widget hosting the persistent bottom navigation panel
class AppCoreSkeleton extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppCoreSkeleton({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = theme.colorScheme.outline;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    final isHome = navigationShell.currentIndex == 0;
    final isFiles = navigationShell.currentIndex == 2;

    final barColor = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFFAFAFA);
    final activeColor = isDark ? Colors.white : Colors.black;
    final inactiveColor = isDark ? Colors.white54 : Colors.black45;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SizedBox(
        height: 68 + bottomPadding,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Bottom Navigation Bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  top: 14,
                  child: Container(
                    decoration: BoxDecoration(
                      color: barColor,
                      border: Border(
                        top: BorderSide(color: borderColor, width: 1),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: bottomPadding),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          // Home Tab - always returns to the Home root grid
                          Expanded(
                            child: _SkeletonNavItem(
                              icon: isHome
                                  ? Icons.home_rounded
                                  : Icons.home_outlined,
                              label: 'Home',
                              isSelected: isHome,
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
                              onTap: () {
                                navigationShell.goBranch(
                                  0,
                                  initialLocation: true,
                                );
                              },
                            ),
                          ),

                          // Center Gap for the Camera Button
                          const SizedBox(width: 64),

                          // Files Tab
                          Expanded(
                            child: _SkeletonNavItem(
                              icon: isFiles
                                  ? Icons.folder_rounded
                                  : Icons.folder_outlined,
                              label: 'Files',
                              isSelected: isFiles,
                              activeColor: activeColor,
                              inactiveColor: inactiveColor,
                              onTap: () {
                                navigationShell.goBranch(
                                  2,
                                  initialLocation: true,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Protruding Center Circular Camera Button in Black & White Theme
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Tooltip(
                      message: 'Scan / Camera',
                      child: Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: () async {
                            await launchDocumentScanner(context, ref);
                          },
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? Colors.white : Colors.black,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF1A1A1A)
                                    : const Color(0xFFE5E5E5),
                                width: 3.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark
                                      ? Colors.black.withValues(alpha: 0.6)
                                      : Colors.black.withValues(alpha: 0.14),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.camera_alt_outlined,
                              size: 23,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
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
  }
}

class _SkeletonNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _SkeletonNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: isSelected ? activeColor : inactiveColor),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? activeColor : inactiveColor,
            ),
          ),
        ],
      ),
    );
  }
}
