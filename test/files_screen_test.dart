import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krocpdf/features/files/data/files_repository.dart';
import 'package:krocpdf/features/files/domain/saved_document.dart';
import 'package:krocpdf/features/files/presentation/files_screen.dart';
import 'package:krocpdf/features/tool_flow/presentation/tool_flow_screen.dart';

void main() {
  testWidgets('FilesScreen shows empty state with Import button and no AppBar Import action or FAB when empty', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: FilesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Files'), findsOneWidget);

    // Verify empty state text and Import button
    expect(find.text('No Saved Files Yet'), findsOneWidget);
    expect(find.text('Import from Device'), findsOneWidget);

    // Verify NO import icon/button in AppBar (only Refresh icon)
    expect(find.byIcon(Icons.refresh_outlined), findsOneWidget);
    expect(find.byIcon(Icons.file_upload), findsNothing);

    // Verify FAB is not shown when files are empty
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('FilesScreen displays FAB when saved documents exist', (tester) async {
    final fakeDoc = SavedDocument(
      id: 'doc_1',
      title: 'Sample_Invoice',
      filePath: '/non_existent/Sample_Invoice.pdf',
      fileSizeBytes: 2048,
      createdAt: DateTime.now(),
      pageCount: 2,
      sourceType: SavedDocumentSource.importFile,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          savedFilesProvider.overrideWith((ref) => FakeSavedFilesNotifier([fakeDoc])),
        ],
        child: const MaterialApp(
          home: FilesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify file card is rendered
    expect(find.text('Sample_Invoice.pdf'), findsOneWidget);
    expect(find.text('No Saved Files Yet'), findsNothing);

    // Verify FAB is present
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Import PDF'), findsOneWidget);
  });

  testWidgets('Tapping Edit on a compiled PDF opens Edit PDF action sheet with tool options', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('kroc_test_');
    final tempFile = File('${tempDir.path}/TestDoc.pdf')..writeAsStringSync('dummy content');

    final fakeDoc = SavedDocument(
      id: 'doc_edit_test',
      title: 'TestDoc',
      filePath: tempFile.path,
      fileSizeBytes: 1024,
      createdAt: DateTime.now(),
      pageCount: 3,
      sourceType: SavedDocumentSource.importFile,
      originalPagePaths: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          savedFilesProvider.overrideWith((ref) => FakeSavedFilesNotifier([fakeDoc])),
        ],
        child: const MaterialApp(
          home: FilesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Find and tap the Edit quick action button on the card
    final editButton = find.text('Edit');
    expect(editButton, findsOneWidget);
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    // Verify Edit PDF action sheet is displayed with tool options
    expect(find.text('Compress PDF'), findsOneWidget);
    expect(find.text('Split PDF'), findsOneWidget);
    expect(find.text('Merge with Another PDF'), findsOneWidget);

    tempDir.deleteSync(recursive: true);
  });

  testWidgets('ToolFlowScreen with initialFilePath preloads file and advances to Step 1', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('kroc_flow_test_');
    final tempFile = File('${tempDir.path}/DocToCompress.pdf')..writeAsStringSync('sample pdf');

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ToolFlowScreen(
            toolId: 'compress_pdf',
            initialFilePath: tempFile.path,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Options step should be displayed directly
    expect(find.text('Options'), findsWidgets);
    expect(find.text('Compress PDF'), findsOneWidget);

    tempDir.deleteSync(recursive: true);
  });
}

class FakeSavedFilesNotifier extends StateNotifier<List<SavedDocument>> implements SavedFilesNotifier {
  FakeSavedFilesNotifier(super.state);

  @override
  Future<void> refresh() async {}

  @override
  Future<void> checkExternalDeletions() async {}

  @override
  Future<SavedDocument> addExternalFile(
    File externalFile, {
    String? customTitle,
    SavedDocumentSource sourceType = SavedDocumentSource.importFile,
  }) async {
    final doc = SavedDocument(
      id: 'doc_${DateTime.now().millisecondsSinceEpoch}',
      title: customTitle ?? 'Imported',
      filePath: externalFile.path,
      fileSizeBytes: 100,
      createdAt: DateTime.now(),
      sourceType: sourceType,
    );
    state = [doc, ...state];
    return doc;
  }

  @override
  Future<SavedDocument> registerSavedPdf({
    required String title,
    required String tempPdfPath,
    required int pageCount,
    SavedDocumentSource sourceType = SavedDocumentSource.scan,
    List<String> originalPages = const [],
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> rename(SavedDocument doc, String newTitle) async {}

  @override
  Future<void> delete(SavedDocument doc) async {}
}
