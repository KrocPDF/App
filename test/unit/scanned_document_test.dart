import 'package:flutter_test/flutter_test.dart';
import 'package:krocpdf/features/tool_flow/domain/scanned_document.dart';

void main() {
  group('ScannedPage Model', () {
    test('initializes with default values and paths', () {
      const page = ScannedPage(id: 'page_1', originalPath: '/data/scan_1.jpg');

      expect(page.id, equals('page_1'));
      expect(page.originalPath, equals('/data/scan_1.jpg'));
      expect(page.activeFilePath, equals('/data/scan_1.jpg'));
      expect(page.rotationDegrees, equals(0));
      expect(page.filter, equals(PageFilter.original));
      expect(page.isModified, isFalse);
    });

    test('rotate90 increments by 90 degrees and wraps at 360', () {
      var page = const ScannedPage(
        id: 'page_1',
        originalPath: '/data/scan_1.jpg',
      );

      page = page.rotate90();
      expect(page.rotationDegrees, equals(90));
      expect(page.isModified, isTrue);

      page = page.rotate90();
      expect(page.rotationDegrees, equals(180));

      page = page.rotate90();
      expect(page.rotationDegrees, equals(270));

      page = page.rotate90();
      expect(page.rotationDegrees, equals(0));
    });

    test('applyFilter updates filter mode', () {
      var page = const ScannedPage(
        id: 'page_1',
        originalPath: '/data/scan_1.jpg',
      );

      page = page.applyFilter(PageFilter.grayscale);
      expect(page.filter, equals(PageFilter.grayscale));
      expect(page.isModified, isTrue);

      page = page.applyFilter(PageFilter.blackAndWhite);
      expect(page.filter, equals(PageFilter.blackAndWhite));
    });

    test('applyCrop overrides activeFilePath with croppedPath', () {
      var page = const ScannedPage(
        id: 'page_1',
        originalPath: '/data/scan_1.jpg',
      );

      page = page.applyCrop('/data/scan_1_cropped.jpg');
      expect(page.croppedPath, equals('/data/scan_1_cropped.jpg'));
      expect(page.activeFilePath, equals('/data/scan_1_cropped.jpg'));
      expect(page.isModified, isTrue);
    });
  });

  group('DocumentEditorState Model', () {
    test('handles reordering pages correctly', () {
      final state = DocumentEditorState(
        documentTitle: 'Test Doc',
        pages: const [
          ScannedPage(id: '1', originalPath: '/path1'),
          ScannedPage(id: '2', originalPath: '/path2'),
          ScannedPage(id: '3', originalPath: '/path3'),
        ],
        selectedPageIndex: 0,
      );

      expect(state.pageCount, equals(3));
      expect(state.currentPage?.id, equals('1'));

      // Move page 0 to index 2
      final reordered = state.reorderPages(0, 3);
      expect(
        reordered.pages.map((p) => p.id).toList(),
        equals(['2', '3', '1']),
      );
      expect(reordered.selectedPageIndex, equals(2));
    });

    test('removes current page and adjusts selected index', () {
      final state = DocumentEditorState(
        documentTitle: 'Test Doc',
        pages: const [
          ScannedPage(id: '1', originalPath: '/path1'),
          ScannedPage(id: '2', originalPath: '/path2'),
        ],
        selectedPageIndex: 1,
      );

      final removed = state.removeCurrentPage();
      expect(removed.pageCount, equals(1));
      expect(removed.pages.first.id, equals('1'));
      expect(removed.selectedPageIndex, equals(0));
    });

    test('renames document title', () {
      const state = DocumentEditorState(documentTitle: 'Old Title');

      final renamed = state.copyWith(documentTitle: 'New Title');
      expect(renamed.documentTitle, equals('New Title'));
    });
  });
}
