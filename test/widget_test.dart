import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krocpdf/app.dart';

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
}
