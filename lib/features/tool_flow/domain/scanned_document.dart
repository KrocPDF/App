enum PageFilter { original, grayscale, blackAndWhite }

class ScannedPage {
  final String id;
  final String originalPath;
  final String? croppedPath;
  final int rotationDegrees; // 0, 90, 180, 270
  final PageFilter filter;

  const ScannedPage({
    required this.id,
    required this.originalPath,
    this.croppedPath,
    this.rotationDegrees = 0,
    this.filter = PageFilter.original,
  });

  /// The active image file path on disk (cropped if available, otherwise original)
  String get activeFilePath => croppedPath ?? originalPath;

  /// Returns true if this page has any user modifications
  bool get isModified =>
      croppedPath != null ||
      rotationDegrees != 0 ||
      filter != PageFilter.original;

  ScannedPage copyWith({
    String? id,
    String? originalPath,
    String? croppedPath,
    int? rotationDegrees,
    PageFilter? filter,
  }) {
    return ScannedPage(
      id: id ?? this.id,
      originalPath: originalPath ?? this.originalPath,
      croppedPath: croppedPath ?? this.croppedPath,
      rotationDegrees: rotationDegrees ?? this.rotationDegrees,
      filter: filter ?? this.filter,
    );
  }

  ScannedPage rotate90() {
    return copyWith(rotationDegrees: (rotationDegrees + 90) % 360);
  }

  ScannedPage applyFilter(PageFilter newFilter) {
    return copyWith(filter: newFilter);
  }

  ScannedPage applyCrop(String newCroppedPath) {
    return copyWith(croppedPath: newCroppedPath);
  }
}

class DocumentEditorState {
  final String documentTitle;
  final List<ScannedPage> pages;
  final int selectedPageIndex;
  final bool isProcessing;
  final String? errorMessage;
  final String? outputPdfPath;

  const DocumentEditorState({
    required this.documentTitle,
    this.pages = const [],
    this.selectedPageIndex = 0,
    this.isProcessing = false,
    this.errorMessage,
    this.outputPdfPath,
  });

  bool get isEmpty => pages.isEmpty;
  bool get isNotEmpty => pages.isNotEmpty;
  int get pageCount => pages.length;

  ScannedPage? get currentPage =>
      (pages.isNotEmpty &&
          selectedPageIndex >= 0 &&
          selectedPageIndex < pages.length)
      ? pages[selectedPageIndex]
      : null;

  DocumentEditorState copyWith({
    String? documentTitle,
    List<ScannedPage>? pages,
    int? selectedPageIndex,
    bool? isProcessing,
    String? errorMessage,
    String? outputPdfPath,
  }) {
    return DocumentEditorState(
      documentTitle: documentTitle ?? this.documentTitle,
      pages: pages ?? this.pages,
      selectedPageIndex: selectedPageIndex ?? this.selectedPageIndex,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: errorMessage,
      outputPdfPath: outputPdfPath ?? this.outputPdfPath,
    );
  }

  DocumentEditorState updateCurrentPage(
    ScannedPage Function(ScannedPage) transform,
  ) {
    if (pages.isEmpty ||
        selectedPageIndex < 0 ||
        selectedPageIndex >= pages.length) {
      return this;
    }
    final updatedPages = List<ScannedPage>.from(pages);
    updatedPages[selectedPageIndex] = transform(
      updatedPages[selectedPageIndex],
    );
    return copyWith(pages: updatedPages);
  }

  DocumentEditorState removeCurrentPage() {
    if (pages.isEmpty ||
        selectedPageIndex < 0 ||
        selectedPageIndex >= pages.length) {
      return this;
    }
    final updatedPages = List<ScannedPage>.from(pages)
      ..removeAt(selectedPageIndex);
    final nextIndex = updatedPages.isEmpty
        ? 0
        : (selectedPageIndex >= updatedPages.length
              ? updatedPages.length - 1
              : selectedPageIndex);
    return copyWith(pages: updatedPages, selectedPageIndex: nextIndex);
  }

  DocumentEditorState reorderPages(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= pages.length ||
        newIndex < 0 ||
        newIndex > pages.length) {
      return this;
    }
    final updatedPages = List<ScannedPage>.from(pages);
    var targetIndex = newIndex;
    if (oldIndex < targetIndex) {
      targetIndex -= 1;
    }
    final item = updatedPages.removeAt(oldIndex);
    updatedPages.insert(targetIndex, item);

    int newSelectedIndex = selectedPageIndex;
    if (selectedPageIndex == oldIndex) {
      newSelectedIndex = targetIndex;
    } else if (oldIndex < selectedPageIndex &&
        targetIndex >= selectedPageIndex) {
      newSelectedIndex -= 1;
    } else if (oldIndex > selectedPageIndex &&
        targetIndex <= selectedPageIndex) {
      newSelectedIndex += 1;
    }

    return copyWith(pages: updatedPages, selectedPageIndex: newSelectedIndex);
  }

  DocumentEditorState addPages(List<String> newPaths) {
    if (newPaths.isEmpty) return this;
    final startIndex = pages.length;
    final newPages = newPaths.asMap().entries.map((entry) {
      return ScannedPage(
        id: 'page_${startIndex + entry.key}_${DateTime.now().millisecondsSinceEpoch}',
        originalPath: entry.value,
      );
    }).toList();

    return copyWith(
      pages: [...pages, ...newPages],
      selectedPageIndex: selectedPageIndex,
    );
  }
}
