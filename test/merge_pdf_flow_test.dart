import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krocpdf/features/tool_flow/presentation/tool_flow_screen.dart';
import 'package:krocpdf/features/tool_flow/presentation/widgets/pdf_password_dialog.dart';

void main() {
  group('Merge PDF UI & Password Dialog', () {
    testWidgets('ToolFlowScreen(merge_pdf) disables Next step with < 2 PDFs', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ToolFlowScreen(toolId: 'merge_pdf')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Merge PDF'), findsOneWidget);
      final nextBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Next step'),
      );
      expect(nextBtn.onPressed, isNull);
    });

    testWidgets(
      'showPdfPasswordDialog shows 1 field with filename when 1 PDF is encrypted',
      (tester) async {
        Map<String, String>? result;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(splashFactory: InkRipple.splashFactory),
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await showPdfPasswordDialog(
                      context: context,
                      encryptedFilePaths: ['/docs/confidential_report.pdf'],
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Password Required'), findsOneWidget);
        expect(find.text('confidential_report.pdf'), findsOneWidget);
        expect(find.byType(TextFormField), findsOneWidget);

        await tester.enterText(find.byType(TextFormField), 'my-pass');
        await tester.tap(find.text('Unlock & Merge'));
        await tester.pumpAndSettle();

        expect(result, equals({'/docs/confidential_report.pdf': 'my-pass'}));
      },
    );

    testWidgets(
      'showPdfPasswordDialog shows 2 stacked fields in one window when both PDFs are encrypted',
      (tester) async {
        Map<String, String>? result;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(splashFactory: InkRipple.splashFactory),
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    result = await showPdfPasswordDialog(
                      context: context,
                      encryptedFilePaths: ['/docs/alpha.pdf', '/docs/beta.pdf'],
                      fileErrors: {'/docs/beta.pdf': 'Incorrect password'},
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Passwords Required'), findsOneWidget);
        expect(find.text('PDF 1: alpha.pdf'), findsOneWidget);
        expect(find.text('PDF 2: beta.pdf'), findsOneWidget);
        expect(find.text('Incorrect password'), findsOneWidget);

        final fields = find.byType(TextFormField);
        expect(fields, findsNWidgets(2));

        // Verify stacked vertically (second field is below first field)
        final firstTop = tester.getTopLeft(fields.at(0)).dy;
        final secondTop = tester.getTopLeft(fields.at(1)).dy;
        expect(secondTop, greaterThan(firstTop));

        await tester.enterText(fields.at(0), 'pass1');
        await tester.enterText(fields.at(1), 'pass2');
        await tester.tap(find.text('Unlock & Merge'));
        await tester.pumpAndSettle();

        expect(
          result,
          equals({'/docs/alpha.pdf': 'pass1', '/docs/beta.pdf': 'pass2'}),
        );
      },
    );
  });
}
