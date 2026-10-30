import 'dart:io';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../services/processing/local_processing_service.dart';
import '../../files/data/files_repository.dart';
import '../../files/domain/saved_document.dart';
import '../domain/scanned_document.dart';

/// Riverpod StateNotifier managing multi-page editing operations.
class DocumentEditorNotifier extends StateNotifier<DocumentEditorState> {
  DocumentEditorNotifier()
      : super(DocumentEditorState(
          documentTitle: 'Scan_${_formatCurrentDate()}',
        ));

  static String _formatCurrentDate() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  void init(List<String> imagePaths, {String? title}) {
    final defaultTitle = title ?? 'Scan_${_formatCurrentDate()}';
    final pages = imagePaths.asMap().entries.map((e) {
      return ScannedPage(
        id: 'page_${e.key}_${DateTime.now().millisecondsSinceEpoch}',
        originalPath: e.value,
      );
    }).toList();

    state = DocumentEditorState(
      documentTitle: defaultTitle,
      pages: pages,
      selectedPageIndex: 0,
      isProcessing: false,
    );
  }

  void selectPage(int index) {
    if (index >= 0 && index < state.pages.length) {
      state = state.copyWith(selectedPageIndex: index);
    }
  }

  void rotateCurrentPage() {
    state = state.updateCurrentPage((page) => page.rotate90());
  }

  void setFilterForCurrentPage(PageFilter filter) {
    state = state.updateCurrentPage((page) => page.applyFilter(filter));
  }

  void cropCurrentPage(String newCroppedPath) {
    state = state.updateCurrentPage((page) => page.applyCrop(newCroppedPath));
  }

  void reorderPages(int oldIndex, int newIndex) {
    state = state.reorderPages(oldIndex, newIndex);
  }

  void deleteCurrentPage() {
    state = state.removeCurrentPage();
  }

  void renameDocument(String newTitle) {
    final trimmed = newTitle.trim();
    if (trimmed.isNotEmpty) {
      state = state.copyWith(documentTitle: trimmed);
    }
  }

  void addPages(List<String> newPaths) {
    state = state.addPages(newPaths);
  }

  void setProcessing(bool processing) {
    state = state.copyWith(isProcessing: processing);
  }

  void setOutputPdf(String pdfPath) {
    state = state.copyWith(
      outputPdfPath: pdfPath,
      isProcessing: false,
    );
  }

  void reset() {
    state = DocumentEditorState(
      documentTitle: 'Scan_${_formatCurrentDate()}',
    );
  }
}

final documentEditorProvider =
    StateNotifierProvider<DocumentEditorNotifier, DocumentEditorState>((ref) {
  return DocumentEditorNotifier();
});

/// Shared review and multi-page editing screen used by BOTH Scan and Image-to-PDF flows.
class DocumentEditorScreen extends ConsumerStatefulWidget {
  const DocumentEditorScreen({super.key});

  @override
  ConsumerState<DocumentEditorScreen> createState() => _DocumentEditorScreenState();
}

class _DocumentEditorScreenState extends ConsumerState<DocumentEditorScreen> {
  final LocalProcessingService _processingService = const LocalProcessingService();

  Future<bool> _confirmDiscard(BuildContext context) async {
    final state = ref.read(documentEditorProvider);
    if (state.isEmpty || state.outputPdfPath != null) {
      return true;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard scan?'),
        content: const Text(
          'Are you sure you want to discard your captured pages and edits? This cannot be undone.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  Future<void> _handleCrop() async {
    final state = ref.read(documentEditorProvider);
    final currentPage = state.currentPage;
    if (currentPage == null) return;

    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: currentPage.activeFilePath,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Page',
            toolbarColor: Colors.black,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: Colors.white,
            backgroundColor: Colors.black,
            dimmedLayerColor: const Color(0xCC000000),
            cropFrameColor: Colors.white,
            cropGridColor: Colors.white24,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Page',
          ),
        ],
      );

      if (croppedFile != null && mounted) {
        ref.read(documentEditorProvider.notifier).cropCurrentPage(croppedFile.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cropping unavailable: $e')),
        );
      }
    }
  }

  void _handleRotate() {
    ref.read(documentEditorProvider.notifier).rotateCurrentPage();
  }

  void _handleFilter() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.read(documentEditorProvider);
    final currentFilter = state.currentPage?.filter ?? PageFilter.original;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Select Filter',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.photo_outlined),
                  title: const Text('Original'),
                  trailing: currentFilter == PageFilter.original
                      ? const Icon(Icons.check, size: 20)
                      : null,
                  onTap: () {
                    ref
                        .read(documentEditorProvider.notifier)
                        .setFilterForCurrentPage(PageFilter.original);
                    Navigator.of(ctx).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.filter_b_and_w_outlined),
                  title: const Text('Grayscale'),
                  trailing: currentFilter == PageFilter.grayscale
                      ? const Icon(Icons.check, size: 20)
                      : null,
                  onTap: () {
                    ref
                        .read(documentEditorProvider.notifier)
                        .setFilterForCurrentPage(PageFilter.grayscale);
                    Navigator.of(ctx).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.contrast_outlined),
                  title: const Text('Black & White (High Contrast)'),
                  trailing: currentFilter == PageFilter.blackAndWhite
                      ? const Icon(Icons.check, size: 20)
                      : null,
                  onTap: () {
                    ref
                        .read(documentEditorProvider.notifier)
                        .setFilterForCurrentPage(PageFilter.blackAndWhite);
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleReorder() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF141414) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(documentEditorProvider);
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Reorder Pages',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ReorderableListView.builder(
                        itemCount: state.pages.length,
                        // ignore: deprecated_member_use
                        onReorder: (oldIndex, newIndex) {
                          ref
                              .read(documentEditorProvider.notifier)
                              .reorderPages(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final page = state.pages[index];
                          return ListTile(
                            key: ValueKey(page.id),
                            leading: Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: theme.colorScheme.outline,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text('Page ${index + 1}'),
                            trailing: const Icon(Icons.drag_handle_outlined),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleDelete() async {
    final state = ref.read(documentEditorProvider);
    if (state.currentPage == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Page'),
        content: Text(
          'Are you sure you want to delete page ${state.selectedPageIndex + 1}? This action cannot be undone.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(documentEditorProvider.notifier).deleteCurrentPage();
      final updated = ref.read(documentEditorProvider);
      if (updated.isEmpty && mounted) {
        context.pop();
      }
    }
  }

  Future<void> _handleRename() async {
    final state = ref.read(documentEditorProvider);
    final textController = TextEditingController(text: state.documentTitle);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Document Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(textController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newTitle != null && mounted) {
      ref.read(documentEditorProvider.notifier).renameDocument(newTitle);
    }
  }

  Future<void> _handleKeepScanning() async {
    try {
      final pictures = await CunningDocumentScanner.getPictures();
      if (pictures != null && pictures.isNotEmpty && mounted) {
        ref.read(documentEditorProvider.notifier).addPages(pictures);
      }
    } on PlatformException catch (e) {
      if (mounted) {
        final isPlayServices =
            e.code.contains('PLAY_SERVICES') || (e.message?.contains('Play Services') == true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPlayServices
                  ? 'Document Scanner requires Google Play Services, which is not available on this device. You can import files via "Image to PDF".'
                  : 'Scanner error: ${e.message ?? e.code}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera scanner unavailable on this device.'),
          ),
        );
      }
    }
  }

  Future<void> _handleSavePdf() async {
    final state = ref.read(documentEditorProvider);
    if (state.isEmpty) return;

    ref.read(documentEditorProvider.notifier).setProcessing(true);

    try {
      final outputPath = await _processingService.compilePagesToPdf(
        pages: state.pages,
        outputFileName: state.documentTitle,
      );

      if (mounted) {
        // Register in persistent files repository
        await ref.read(savedFilesProvider.notifier).registerSavedPdf(
              title: state.documentTitle,
              tempPdfPath: outputPath,
              pageCount: state.pageCount,
              sourceType: SavedDocumentSource.scan,
              originalPages: state.pages.map((p) => p.originalPath).toList(),
            );

        if (!mounted) return;

        ref.read(documentEditorProvider.notifier).reset();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document saved: "${state.documentTitle}.pdf"'),
            duration: const Duration(seconds: 3),
          ),
        );

        // Auto-navigate to Files tab so user sees the newly created document at the top
        context.go('/files');
      }
    } catch (e) {
      if (mounted) {
        ref.read(documentEditorProvider.notifier).setProcessing(false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to compile PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = theme.colorScheme.outline;
    final state = ref.watch(documentEditorProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscard(context);
        if (shouldPop && context.mounted) {
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_outlined),
            onPressed: () async {
              final shouldPop = await _confirmDiscard(context);
              if (shouldPop && context.mounted) {
                context.pop();
              }
            },
          ),
          title: InkWell(
            onTap: _handleRename,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    state.documentTitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.edit_outlined, size: 16),
              ],
            ),
          ),
          actions: [
            if (state.outputPdfPath == null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ElevatedButton(
                  onPressed: state.isProcessing ? null : _handleSavePdf,
                  child: state.isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save PDF'),
                ),
              ),
          ],
        ),
        body: state.outputPdfPath != null
            ? _buildResultView(context, state, isDark, borderColor)
            : _buildEditorView(context, state, isDark, borderColor),
      ),
    );
  }

  Widget _buildEditorView(
    BuildContext context,
    DocumentEditorState state,
    bool isDark,
    Color borderColor,
  ) {
    if (state.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.document_scanner_outlined, size: 48),
            const SizedBox(height: 16),
            const Text('No pages captured.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      );
    }

    final currentPage = state.currentPage!;

    return Column(
      children: [
        // Page Counter Indicator
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          color: isDark ? const Color(0xFF141414) : const Color(0xFFF7F7F7),
          alignment: Alignment.center,
          child: Text(
            'Page ${state.selectedPageIndex + 1} of ${state.pageCount}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),

        // Center Large Interactive Preview
        Expanded(
          child: Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor, width: 1),
                    color: isDark ? const Color(0xFF141414) : const Color(0xFFEEEEEE),
                  ),
                  child: _buildImagePreview(currentPage, isDark),
                ),
              ),
            ),
          ),
        ),

        // Bottom Page Thumbnails Strip
        Container(
          height: 96,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0C0C0C) : const Color(0xFFFAFAFA),
            border: Border(
              top: BorderSide(color: borderColor, width: 1),
              bottom: BorderSide(color: borderColor, width: 1),
            ),
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: state.pages.length + 1,
            itemBuilder: (context, index) {
              if (index == state.pages.length) {
                // "Keep scanning" / "Add page" button
                return InkWell(
                  onTap: _handleKeepScanning,
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor, width: 1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo_outlined, size: 20),
                        const SizedBox(height: 4),
                        Text(
                          'Scan',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final page = state.pages[index];
              final isSelected = index == state.selectedPageIndex;

              return InkWell(
                onTap: () {
                  ref.read(documentEditorProvider.notifier).selectPage(index);
                },
                child: Container(
                  width: 60,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected
                          ? (isDark ? Colors.white : Colors.black)
                          : borderColor,
                      width: isSelected ? 2.0 : 1.0,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: _buildImagePreview(page, isDark, isThumbnail: true),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        left: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Bottom Action Toolbar (Strictly 6 Actions)
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0C0C0C) : const Color(0xFFFAFAFA),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ToolbarButton(
                icon: Icons.crop_outlined,
                label: 'Crop',
                onTap: _handleCrop,
              ),
              _ToolbarButton(
                icon: Icons.rotate_right_outlined,
                label: 'Rotate',
                onTap: _handleRotate,
              ),
              _ToolbarButton(
                icon: Icons.tune_outlined,
                label: 'Filter',
                onTap: _handleFilter,
              ),
              _ToolbarButton(
                icon: Icons.swap_horiz_outlined,
                label: 'Reorder',
                onTap: _handleReorder,
              ),
              _ToolbarButton(
                icon: Icons.delete_outline,
                label: 'Delete',
                onTap: _handleDelete,
              ),
              _ToolbarButton(
                icon: Icons.edit_outlined,
                label: 'Rename',
                onTap: _handleRename,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultView(
    BuildContext context,
    DocumentEditorState state,
    bool isDark,
    Color borderColor,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor, width: 2),
                  borderRadius: BorderRadius.circular(36),
                ),
                child: const Icon(Icons.check_outlined, size: 36),
              ),
              const SizedBox(height: 20),
              const Text(
                'PDF Ready',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${state.documentTitle}.pdf (${state.pageCount} pages)',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                state.outputPdfPath ?? '',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(documentEditorProvider.notifier).reset();
                    context.go('/');
                  },
                  child: const Text('Back to Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(ScannedPage page, bool isDark, {bool isThumbnail = false}) {
    final file = File(page.activeFilePath);
    Widget imageWidget;

    if (file.existsSync()) {
      imageWidget = Image.file(
        file,
        fit: isThumbnail ? BoxFit.cover : BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(page, isDark),
      );
    } else {
      imageWidget = _buildPlaceholder(page, isDark);
    }

    // Apply rotation
    if (page.rotationDegrees != 0) {
      imageWidget = RotatedBox(
        quarterTurns: (page.rotationDegrees % 360) ~/ 90,
        child: imageWidget,
      );
    }

    // Apply filter in preview
    if (page.filter == PageFilter.grayscale) {
      imageWidget = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]),
        child: imageWidget,
      );
    } else if (page.filter == PageFilter.blackAndWhite) {
      imageWidget = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          2.0, 2.0, 2.0, 0, -200,
          2.0, 2.0, 2.0, 0, -200,
          2.0, 2.0, 2.0, 0, -200,
          0,   0,   0,   1, 0,
        ]),
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildPlaceholder(ScannedPage page, bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE0E0E0),
      alignment: Alignment.center,
      child: Icon(
        Icons.description_outlined,
        color: isDark ? Colors.white38 : Colors.black38,
        size: 32,
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: isDark ? Colors.white : Colors.black),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
