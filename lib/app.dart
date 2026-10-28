import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/settings/presentation/settings_screen.dart';
import 'features/tool_flow/presentation/tool_detail_screen.dart';
import 'features/tool_flow/presentation/tool_flow_screen.dart';

final GoRouter _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: 'settings',
          builder: (context, state) => const SettingsScreen(),
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
                return ToolFlowScreen(toolId: toolId, format: format);
              },
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
