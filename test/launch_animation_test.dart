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

  group('LaunchTimelineState exact mathematical formulas (3.2s duration)', () {
    test('t = 0.4s: Paper dropping from top', () {
      final s = LaunchTimelineState.compute(0.4);
      expect(s.paperY, closeTo(16.0, 0.1));
      expect(s.paperOpacity, equals(1.0));
      expect(s.fold, equals(0.0));
      expect(s.crocX, equals(-280.0));
      expect(s.mouthA, equals(0.0));
      expect(s.pdfScale, equals(1.0));
      expect(s.sceneOpacity, equals(1.0));
    });

    test('t = 0.8s: Corner folded, badge visible', () {
      final s = LaunchTimelineState.compute(0.8);
      expect(s.paperY, equals(0.0));
      expect(s.fold, closeTo(9.0, 0.1));
      expect(s.textLinesOpacity, closeTo(0.54, 0.05));
      expect(s.pdfBadgeOpacity, closeTo(0.40, 0.05));
      expect(s.crocX, equals(-280.0));
      expect(s.pdfScale, equals(1.0));
    });

    test('t = 1.5s: Croc at -20 with mouth wide open around paper', () {
      final s = LaunchTimelineState.compute(1.5);
      expect(s.paperY, equals(0.0));
      expect(s.fold, equals(18.0));
      expect(s.crocX, closeTo(-20.0, 0.1));
      expect(s.mouthA, closeTo(1.0, 0.05));
      expect(s.pdfScale, equals(1.0));
      expect(s.pdfOpacity, equals(1.0));
    });

    test('t = 1.7s: Jaws clamped shut, PDF file eaten', () {
      final s = LaunchTimelineState.compute(1.7);
      expect(s.mouthA, closeTo(0.0, 0.001));
      expect(s.pdfScale, closeTo(0.0, 0.001));
      expect(s.pdfOpacity, closeTo(0.0, 0.001));
    });

    test('t = 2.4s: Croc moving rightward, wordmark revealing', () {
      final s = LaunchTimelineState.compute(2.4);
      expect(s.crocX, greaterThan(300.0));
      expect(s.revealProgress, closeTo(0.85, 0.1));
      expect(s.sceneOpacity, equals(1.0));
    });

    test('t = 3.2s: Sequence ends with scene opacity = 0.0', () {
      final s = LaunchTimelineState.compute(3.2);
      expect(s.sceneOpacity, closeTo(0.0, 0.001));
    });
  });

  group('LaunchAnimationScreen widget tests', () {
    testWidgets('LaunchGate shows LaunchAnimationScreen on cold start and transitions to Home at 3.2s', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: KrocApp(),
        ),
      );

      // Initial frame shows the launch animation screen
      expect(find.byType(LaunchAnimationScreen), findsOneWidget);

      // Pump through the 3200ms timeline
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byType(LaunchAnimationScreen), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.byType(LaunchAnimationScreen), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1000));
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
