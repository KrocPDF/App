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

  group('LaunchTimelineState exact mathematical formulas', () {
    test('t = 0.5s: Paper dropping with overshoot, croc off-screen, mouth closed', () {
      final s = LaunchTimelineState.compute(0.5);
      expect(s.top, closeTo(255.95, 0.1));
      expect(s.fold, equals(0.0));
      expect(s.textLinesOpacity, equals(0.0));
      expect(s.pdfBadgeOpacity, equals(0.0));
      expect(s.crocX, equals(-230.0));
      expect(s.mouthA, equals(0.0));
      expect(s.crocScale, equals(1.0));
      expect(s.iconXOffset, equals(0.0));
      expect(s.wordmarkVisible, isFalse);
      expect(s.sceneOpacity, equals(1.0));
    });

    test('t = 1.2s: Corner folding, text & badge fading, croc entering, mouth opening', () {
      final s = LaunchTimelineState.compute(1.2);
      expect(s.top, equals(226.0));
      expect(s.fold, closeTo(12.0, 0.01));
      expect(s.textLinesOpacity, closeTo(0.675, 0.001));
      expect(s.pdfBadgeOpacity, closeTo(0.50, 0.001));
      expect(s.crocX, closeTo(-89.26, 0.1));
      expect(s.mouthA, closeTo(0.8285, 0.01));
      expect(s.crocScale, equals(1.0));
      expect(s.iconXOffset, equals(0.0));
      expect(s.wordmarkVisible, isFalse);
      expect(s.sceneOpacity, equals(1.0));
    });

    test('t = 1.7s: Lunge forward, jaws snapping shut on icon, scale pulse', () {
      final s = LaunchTimelineState.compute(1.7);
      expect(s.top, equals(226.0));
      expect(s.fold, equals(18.0));
      expect(s.textLinesOpacity, equals(0.9));
      expect(s.pdfBadgeOpacity, equals(1.0));
      expect(s.crocX, closeTo(-18.0, 0.01));
      expect(s.mouthA, closeTo(0.8790, 0.01));
      expect(s.crocScale, closeTo(1.0469, 0.001));
      expect(s.iconRotate, equals(0.0));
      expect(s.iconScale, equals(1.0));
      expect(s.iconXOffset, equals(0.0));
      expect(s.wordmarkVisible, isFalse);
      expect(s.sceneOpacity, equals(1.0));
    });

    test('t = 2.2s: Croc exiting right with icon, chewing decaying, wordmark wiping open', () {
      final s = LaunchTimelineState.compute(2.2);
      expect(s.top, equals(226.0));
      expect(s.fold, equals(18.0));
      expect(s.crocX, closeTo(65.86, 0.1));
      expect(s.mouthA, closeTo(0.0300, 0.01));
      expect(s.crocScale, equals(1.0));
      expect(s.iconRotate, closeTo(-10.0 * (math.pi / 180.0), 0.001));
      expect(s.iconScale, closeTo(0.85, 0.001));
      expect(s.iconXOffset, closeTo(65.86, 0.1));
      expect(s.wordmarkVisible, isTrue);
      expect(s.revealX, closeTo(109.39, 0.1));
      expect(s.sceneOpacity, equals(1.0));
    });

    test('t = 3.0s: Croc nearly exited, chewing done (A=0), wordmark fully revealed (330)', () {
      final s = LaunchTimelineState.compute(3.0);
      expect(s.top, equals(226.0));
      expect(s.crocX, closeTo(414.62, 0.2));
      expect(s.mouthA, equals(0.0));
      expect(s.crocScale, equals(1.0));
      expect(s.iconXOffset, closeTo(414.62, 0.2));
      expect(s.wordmarkVisible, isTrue);
      expect(s.revealX, equals(330.0));
      expect(s.sceneOpacity, equals(1.0));
    });

    test('t = 3.9s: Hold finished, croc off-screen, scene fading out (75% opacity)', () {
      final s = LaunchTimelineState.compute(3.9);
      expect(s.crocX, equals(420.0));
      expect(s.mouthA, equals(0.0));
      expect(s.wordmarkVisible, isTrue);
      expect(s.revealX, equals(330.0));
      expect(s.sceneOpacity, closeTo(0.75, 0.01));
    });

    test('t = 4.2s: Sequence ends with scene opacity = 0.0', () {
      final s = LaunchTimelineState.compute(4.2);
      expect(s.sceneOpacity, equals(0.0));
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
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byType(LaunchAnimationScreen), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byType(LaunchAnimationScreen), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byType(LaunchAnimationScreen), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1200));
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
