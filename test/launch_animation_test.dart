import 'dart:math' as math;
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

  group('LaunchTimelineState exact mathematical formulas (4.2s duration)', () {
    test('t = 0.5s: Paper dropping with overshoot, croc off-screen, mouth closed', () {
      final s = LaunchTimelineState.compute(0.5);
      expect(s.paperY, closeTo(14.06, 0.1));
      expect(s.paperOpacity, equals(1.0));
      expect(s.fold, equals(0.0));
      expect(s.textLinesOpacity, equals(0.0));
      expect(s.pdfBadgeOpacity, equals(0.0));
      expect(s.crocX, equals(-230.0));
      expect(s.mouthA, equals(0.0));
      expect(s.crocScale, equals(1.0));
      expect(s.iconRotate, equals(0.0));
      expect(s.sceneOpacity, equals(1.0));
    });

    test('t = 1.0s: Corner folded, text & badge visible, croc entering', () {
      final s = LaunchTimelineState.compute(1.0);
      expect(s.paperY, equals(0.0));
      expect(s.fold, closeTo(6.0, 0.1));
      expect(s.textLinesOpacity, closeTo(0.22, 0.05));
      expect(s.pdfBadgeOpacity, equals(0.0));
      expect(s.crocX, equals(-230.0));
      expect(s.mouthA, equals(0.0));
      expect(s.crocScale, equals(1.0));
      expect(s.iconRotate, equals(0.0));
      expect(s.sceneOpacity, equals(1.0));
    });

    test('t = 1.5s: Croc entering from left with open jaw', () {
      final s = LaunchTimelineState.compute(1.5);
      expect(s.paperY, equals(0.0));
      expect(s.fold, equals(18.0));
      expect(s.crocX, closeTo(-30.93, 0.1));
      expect(s.mouthA, closeTo(1.0, 0.05));
      expect(s.crocScale, equals(1.0));
      expect(s.iconRotate, equals(0.0));
      expect(s.sceneOpacity, equals(1.0));
    });

    test('t = 1.85s: Jaws clamped, PDF icon tilted -10°', () {
      final s = LaunchTimelineState.compute(1.85);
      expect(s.crocX, equals(0.0));
      expect(s.mouthA, equals(0.0));
      expect(s.crocScale, closeTo(1.04, 0.05));
      expect(s.iconRotate, closeTo(-10.0 * (math.pi / 180.0), 0.001));
      expect(s.iconScale, closeTo(0.85, 0.01));
      expect(s.iconXOffset, closeTo(-12.0, 0.01));
      expect(s.sceneOpacity, equals(1.0));
    });

    test('t = 3.0s: Croc exiting to the right, wordmark fully revealed', () {
      final s = LaunchTimelineState.compute(3.0);
      expect(s.crocX, greaterThan(350.0));
      expect(s.revealProgress, equals(1.0));
      expect(s.sceneOpacity, equals(1.0));
    });

    test('t = 4.2s: Sequence ends with scene opacity = 0.0', () {
      final s = LaunchTimelineState.compute(4.2);
      expect(s.sceneOpacity, closeTo(0.0, 0.001));
    });
  });

  group('LaunchAnimationScreen widget tests', () {
    testWidgets('LaunchGate shows LaunchAnimationScreen on cold start and transitions to Home at 4.2s', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: KrocApp(),
        ),
      );

      // Initial frame shows the launch animation screen
      expect(find.byType(LaunchAnimationScreen), findsOneWidget);

      // Pump through the 4200ms timeline
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.byType(LaunchAnimationScreen), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.byType(LaunchAnimationScreen), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();

      // After animation completes, LaunchAnimationScreen is dismissed and Home is visible
      expect(find.byType(LaunchAnimationScreen), findsNothing);
      expect(LaunchGate.hasCompletedLaunch, isTrue);
      expect(find.text('Confidential'), findsOneWidget);
    });

    testWidgets('LaunchGate does NOT replay animation on warm resume / subsequent build', (tester) async {
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
  });
}
