import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krocpdf/app.dart';
import 'package:krocpdf/features/tool_flow/presentation/document_editor_screen.dart';

void main() {
  testWidgets('Home screen displays all 8 tool buttons and mode selector', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KrocApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify app title and mode selector
    expect(find.text('KrocPDF'), findsOneWidget);
    expect(find.text('Confidential'), findsOneWidget);
    expect(find.text('Non-Confidential'), findsOneWidget);

    // Verify all 8 tool buttons are present
    expect(find.text('Merge PDF'), findsOneWidget);
    expect(find.text('Split PDF'), findsOneWidget);
    expect(find.text('Compress PDF'), findsOneWidget);
    expect(find.text('Lock PDF'), findsOneWidget);
    expect(find.text('Unlock PDF'), findsOneWidget);
    expect(find.text('Image Convert'), findsOneWidget);
    expect(find.text('Image to PDF'), findsOneWidget);
    expect(find.text('Office to PDF'), findsOneWidget);
  });

  testWidgets('Home screen renders without overflow on narrow mobile screens (360x640)', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: KrocApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Merge PDF'), findsOneWidget);
  });

  testWidgets('Home screen renders without overflow on extra small mobile screens (320x568)', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: KrocApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Merge PDF'), findsOneWidget);
  });

  testWidgets('Core skeleton renders bottom navigation panel in black & white theme', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KrocApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);

    // Navigate to a tool (Merge PDF) - bottom nav bar must stay visible
    await tester.tap(find.text('Merge PDF'));
    await tester.pumpAndSettle();

    expect(find.text('Select Format'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt_outlined), findsOneWidget);

    // Tapping Home resets directly back to root Home tool grid
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.text('Tools'), findsOneWidget);
    expect(find.text('Merge PDF'), findsOneWidget);
  });

  testWidgets('DocumentEditorScreen renders page strip and exactly 6 toolbar actions', (tester) async {
    final container = ProviderContainer();
    container.read(documentEditorProvider.notifier).init(
      ['/fake/page_1.jpg', '/fake/page_2.jpg'],
      title: 'Invoice_2026',
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: DocumentEditorScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title and page counter
    expect(find.text('Invoice_2026'), findsOneWidget);
    expect(find.text('Page 1 of 2'), findsOneWidget);
    expect(find.text('Save PDF'), findsOneWidget);

    // Verify exactly the 6 required bottom toolbar actions
    expect(find.text('Crop'), findsOneWidget);
    expect(find.text('Rotate'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('Reorder'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Rename'), findsOneWidget);

    // Verify page strip has thumbnails and "Scan" (Keep scanning) button
    expect(find.text('1'), findsWidgets);
    expect(find.text('2'), findsWidgets);
    expect(find.text('Scan'), findsOneWidget);

    // Test Rotate action
    await tester.tap(find.text('Rotate'));
    await tester.pumpAndSettle();
    expect(container.read(documentEditorProvider).currentPage?.rotationDegrees, equals(90));
  });
}
