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
    test('t = 0.2s: Paper dropping from top', () {
      final s = LaunchTimelineState.compute(0.2);
      expect(s.paperY, lessThan(0.0));
      expect(s.paperOpacity, greaterThan(0.5));
      expect(s.fold, equals(0.0));
      expect(s.crocX, equals(-320.0));
      expect(s.mouthA, equals(0.0));
      expect(s.pdfScale, equals(1.0));
      expect(s.sceneOpacity, equals(1.0));
    });

    test('t = 1.6s: Corner folded, badge visible', () {
      final s = LaunchTimelineState.compute(1.6);
      expect(s.paperY, equals(0.0));
      expect(s.fold, greaterThan(0.0));
      expect(s.textLinesOpacity, greaterThan(0.0));
      expect(s.pdfBadgeOpacity, greaterThan(0.0));
      expect(s.crocX, equals(-320.0));
      expect(s.pdfScale, equals(1.0));
    });

    test('t = 2.65s: Croc framing paper with mouth wide open', () {
      final s = LaunchTimelineState.compute(2.65);
      expect(s.paperY, equals(0.0));
      expect(s.fold, equals(18.0));
      expect(s.crocX, closeTo(-35.0, 1.0));
      expect(s.mouthA, closeTo(1.0, 0.05));
      expect(s.pdfScale, equals(1.0));
      expect(s.pdfOpacity, equals(1.0));
    });

    test('t = 2.95s: Jaws clamped shut, PDF file clamped and traveling with croc', () {
      final s = LaunchTimelineState.compute(2.95);
      expect(s.pdfOpacity, equals(1.0));
      expect(s.paperX, greaterThan(0.0));
    });

    test('t = 3.6s: Croc moving rightward carrying paper, wordmark revealing', () {
      final s = LaunchTimelineState.compute(3.6);
      expect(s.crocX, greaterThan(200.0));
      expect(s.paperX, greaterThan(200.0));
      expect(s.revealProgress, greaterThan(0.5));
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

      await tester.pump(const Duration(milliseconds: 1500));
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
