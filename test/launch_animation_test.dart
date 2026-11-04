import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krocpdf/app.dart';
import 'package:krocpdf/features/launch/presentation/launch_animation_screen.dart';
import 'package:krocpdf/features/launch/presentation/launch_gate.dart';

void main() {
  setUp(() {
    LaunchGate.resetColdStartFlagForTesting();
  });

  testWidgets('LaunchGate shows LaunchAnimationScreen on cold start and transitions to Home', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KrocApp(),
      ),
    );

    // Initial frame shows the launch animation screen
    expect(find.byType(LaunchAnimationScreen), findsOneWidget);

    // Pump frames to advance through the animation stages
    await tester.pump(const Duration(milliseconds: 700)); // Paper dropped
    expect(find.byType(LaunchAnimationScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700)); // Paper folded into PDF
    expect(find.byType(LaunchAnimationScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 800)); // Croc eats PDF
    expect(find.byType(LaunchAnimationScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600)); // Wordmark revealed & holding
    expect(find.text('KrocPDF'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 400)); // Fade out & completion
    await tester.pumpAndSettle();

    // After animation completes, LaunchAnimationScreen is dismissed and Home is visible
    expect(find.byType(LaunchAnimationScreen), findsNothing);
    expect(LaunchGate.hasCompletedLaunch, isTrue);
    expect(find.text('Confidential'), findsOneWidget);
  });

  testWidgets('Tapping anywhere skips the launch animation and proceeds to Home immediately', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KrocApp(),
      ),
    );

    expect(find.byType(LaunchAnimationScreen), findsOneWidget);

    // Tap anywhere on screen during animation
    await tester.tap(find.byType(LaunchAnimationScreen));
    await tester.pumpAndSettle();

    // Immediately dismissed to Home
    expect(find.byType(LaunchAnimationScreen), findsNothing);
    expect(LaunchGate.hasCompletedLaunch, isTrue);
    expect(find.text('Confidential'), findsOneWidget);
  });

  testWidgets('LaunchGate does NOT replay animation on warm resume / subsequent build', (tester) async {
    // Set flag to true as if cold start already completed
    LaunchGate.hasCompletedLaunch = true;

    await tester.pumpWidget(
      const ProviderScope(
        child: KrocApp(),
      ),
    );
    await tester.pump();

    // Immediately shows Home without building LaunchAnimationScreen
    expect(find.byType(LaunchAnimationScreen), findsNothing);
    expect(find.text('Confidential'), findsOneWidget);
  });

  testWidgets('LaunchAnimationScreen respects disableAnimations and skips full motion', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            child: LaunchAnimationScreen(
              onComplete: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    // In reduced motion mode, wordmark is rendered statically
    expect(find.text('KrocPDF'), findsOneWidget);
    expect(find.text('Fast. Private. On-device.'), findsOneWidget);
  });
}
