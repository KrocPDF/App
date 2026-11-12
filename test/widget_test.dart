import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krocpdf/app.dart';
import 'package:krocpdf/core/constants/app_limits.dart';
import 'package:krocpdf/core/errors/app_error.dart';
import 'package:krocpdf/core/result/result.dart';
import 'package:krocpdf/features/home/domain/app_mode.dart';
import 'package:krocpdf/features/tool_flow/presentation/document_editor_screen.dart';
import 'package:krocpdf/features/tool_flow/presentation/tool_flow_screen.dart';
import 'package:krocpdf/services/file_validation_service.dart';

void main() {
  testWidgets(
    'Home screen in Confidential mode displays only 5 on-device tools (excludes Office and Lock/Unlock)',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: KrocApp()));
      await tester.pumpAndSettle();

      // Verify app title and mode selector
      expect(find.text('KrocPDF'), findsOneWidget);
      expect(find.text('Confidential'), findsOneWidget);
      expect(find.text('Non-Confidential'), findsOneWidget);

      // Verify the 5 on-device tools are present
      expect(find.text('Merge PDF'), findsOneWidget);
      expect(find.text('Split PDF'), findsOneWidget);
      expect(find.text('Compress PDF'), findsOneWidget);
      expect(find.text('Image Convert'), findsOneWidget);
      expect(find.text('Image to PDF'), findsOneWidget);

      // Verify Lock PDF and Unlock PDF are completely removed
      expect(find.text('Lock PDF'), findsNothing);
      expect(find.text('Unlock PDF'), findsNothing);

      // Verify Office to PDF is hidden in Confidential mode
      expect(find.text('Office to PDF'), findsNothing);
    },
  );

  testWidgets(
    'Home screen displays Office to PDF when switched to Non-Confidential mode',
    (tester) async {
      final container = ProviderContainer();
      container.read(appModeProvider.notifier).state = AppMode.nonConfidential;

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const KrocApp()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Office to PDF'), findsOneWidget);
      expect(find.text('Lock PDF'), findsNothing);
      expect(find.text('Unlock PDF'), findsNothing);
    },
  );

  testWidgets(
    'Home screen renders without overflow on narrow mobile screens (360x640)',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ProviderScope(child: KrocApp()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Merge PDF'), findsOneWidget);
    },
  );

  testWidgets(
    'Home screen renders without overflow on extra small mobile screens (320x568)',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ProviderScope(child: KrocApp()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Merge PDF'), findsOneWidget);
    },
  );

  testWidgets(
    'Core skeleton renders bottom navigation panel in black & white theme',
    (tester) async {
      await tester.pumpWidget(const ProviderScope(child: KrocApp()));
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
    },
  );

  testWidgets(
    'DocumentEditorScreen renders page strip and exactly 6 toolbar actions',
    (tester) async {
      final container = ProviderContainer();
      container.read(documentEditorProvider.notifier).init([
        '/fake/page_1.jpg',
        '/fake/page_2.jpg',
      ], title: 'Invoice_2026');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DocumentEditorScreen()),
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
      expect(
        container.read(documentEditorProvider).currentPage?.rotationDegrees,
        equals(90),
      );
    },
  );

  testWidgets(
    'Image Convert tool displays HEIC format option in ToolDetailScreen',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ProviderScope(child: KrocApp()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Image Convert'));
      await tester.pumpAndSettle();

      // Verify HEIC is listed as a selectable format option along with JPG, PNG, WEBP
      expect(find.text('HEIC'), findsOneWidget);
      expect(find.text('JPG'), findsOneWidget);
      expect(find.text('PNG'), findsOneWidget);
      expect(find.text('WEBP'), findsOneWidget);
    },
  );

  testWidgets(
    'Image Convert options shows lossless size note for PNG and WEBP, hides for JPG and HEIC',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ToolFlowScreen(
              toolId: 'image_convert',
              format: 'JPG',
              initialStepIndex: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      const pngNote =
          'PNG is lossless — output may be larger than the original file.';
      const webpNote = 'WEBP output may be larger than the original file.';

      // Default target format is JPG: no lossless size note, quality slider visible
      expect(find.text(pngNote), findsNothing);
      expect(find.text(webpNote), findsNothing);
      expect(find.text('Compression Quality'), findsOneWidget);

      // Select PNG: lossless note appears, quality slider hidden
      await tester.tap(find.widgetWithText(ChoiceChip, 'PNG'));
      await tester.pumpAndSettle();
      expect(find.text(pngNote), findsOneWidget);
      expect(find.text(webpNote), findsNothing);
      expect(find.text('Compression Quality'), findsNothing);

      // Select WEBP: WEBP size note appears, quality slider visible
      await tester.tap(find.widgetWithText(ChoiceChip, 'WEBP'));
      await tester.pumpAndSettle();
      expect(find.text(pngNote), findsNothing);
      expect(find.text(webpNote), findsOneWidget);
      expect(find.text('Compression Quality'), findsOneWidget);

      // Select HEIC: size note hidden, quality slider visible
      await tester.tap(find.widgetWithText(ChoiceChip, 'HEIC'));
      await tester.pumpAndSettle();
      expect(find.text(pngNote), findsNothing);
      expect(find.text(webpNote), findsNothing);
      expect(find.text('Compression Quality'), findsOneWidget);

      // Select JPG: size note hidden, quality slider visible
      await tester.tap(find.widgetWithText(ChoiceChip, 'JPG'));
      await tester.pumpAndSettle();
      expect(find.text(pngNote), findsNothing);
      expect(find.text(webpNote), findsNothing);
      expect(find.text('Compression Quality'), findsOneWidget);
    },
  );

  test(
    'FileValidationService correctly validates file size and extensions',
    () {
      const validator = LocalFileValidationService();

      // Size check
      final validSize = validator.validateSizeBytes(50 * 1024 * 1024);
      expect(validSize is Success, isTrue);

      final oversized = validator.validateSizeBytes(
        AppLimits.maxLocalFileBytes + 1,
      );
      expect(oversized is Failure, isTrue);
      expect((oversized as Failure).error, isA<FileTooLarge>());

      // Extension check
      final validPdf = validator.validateExtension('document.pdf', ['pdf']);
      expect(validPdf is Success, isTrue);

      final validHeic = validator.validateExtension('photo.HEIC', [
        'heic',
        'jpg',
        'png',
      ]);
      expect(validHeic is Success, isTrue);

      final invalidExe = validator.validateExtension('malicious.exe', [
        'pdf',
        'jpg',
      ]);
      expect(invalidExe is Failure, isTrue);
      expect((invalidExe as Failure).error, isA<UnsupportedType>());
    },
  );

  testWidgets(
    'Compress PDF Options displays presets, slider, and Compress PDF button',
    (tester) async {
      final tempDir = Directory.systemTemp.createTempSync(
        'compress_flow_test_',
      );
      final tempPdf = File('${tempDir.path}/sample.pdf');
      tempPdf.writeAsBytesSync([1, 2, 3, 4, 5]);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ToolFlowScreen(
              toolId: 'compress_pdf',
              initialFilePath: tempPdf.path,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify presets are displayed
      expect(find.text('Recommended'), findsOneWidget);
      expect(find.text('Extreme'), findsOneWidget);
      expect(find.text('Basic'), findsOneWidget);

      // Verify slider is present
      expect(find.byType(Slider), findsOneWidget);

      // Verify button says "Compress PDF"
      expect(
        find.widgetWithText(ElevatedButton, 'Compress PDF'),
        findsOneWidget,
      );

      // Verify on-device notice
      expect(find.textContaining('100% confidential'), findsOneWidget);

      tempDir.deleteSync(recursive: true);
    },
  );
}
