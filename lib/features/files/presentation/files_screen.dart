import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/result/result.dart';
import '../../../core/utils/storage_permission_helper.dart';
import '../../../services/file_validation_service.dart';
import '../../tool_flow/presentation/document_editor_screen.dart';
import '../data/files_repository.dart';
import '../domain/saved_document.dart';
import 'pdf_viewer_screen.dart';

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      ref.read(savedFilesProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(savedFilesProvider.notifier).checkExternalDeletions();
    }
  }

  Future<void> _handleView(SavedDocument doc) async {
    final file = File(doc.filePath);
    if (!await file.exists()) {
      _showFileNotFoundSnackBar();
      ref.read(savedFilesProvider.notifier).checkExternalDeletions();
      return;
    }
    if (doc.filePath.toLowerCase().endsWith('.pdf')) {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PdfViewerScreen(
              filePath: doc.filePath,
              title: doc.title,
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: Colors.black,
                    child: InteractiveViewer(
                      child: Image.file(file, fit: BoxFit.contain),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleShare(SavedDocument doc) async {
    final file = File(doc.filePath);
    if (!await file.exists()) {
      _showFileNotFoundSnackBar();
      ref.read(savedFilesProvider.notifier).checkExternalDeletions();
      return;
    }
    // ignore: deprecated_member_use
    await Share.shareXFiles(
      [XFile(doc.filePath)],
    );
  }

  Future<void> _handlePrint(SavedDocument doc) async {
    final file = File(doc.filePath);
    if (!await file.exists()) {
      _showFileNotFoundSnackBar();
      ref.read(savedFilesProvider.notifier).checkExternalDeletions();
      return;
    }
    try {
      final bytes = await file.readAsBytes();
      await Printing.layoutPdf(
        onLayout: (_) => bytes,
        name: doc.title,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print failed: $e')),
        );
      }
    }
  }

  Future<void> _handleEdit(SavedDocument doc) async {
    final file = File(doc.filePath);
    if (!await file.exists()) {
      _showFileNotFoundSnackBar();
      ref.read(savedFilesProvider.notifier).checkExternalDeletions();
      return;
    }

    // If document has original scan pages captured, reopen them in the editor for re-cropping & filters
    if (doc.originalPagePaths.isNotEmpty) {
      ref.read(documentEditorProvider.notifier).init(
            doc.originalPagePaths,
            title: doc.title,
          );
      if (mounted) {
        context.push('/edit-document');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Reopening compiled PDF "${doc.title}". You can compress or convert it.',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _handleRename(SavedDocument doc) async {
    final textController = TextEditingController(text: doc.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename File'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'File Name',
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

    if (newTitle != null && newTitle.trim().isNotEmpty && mounted) {
      await ref.read(savedFilesProvider.notifier).rename(doc, newTitle);
    }
  }

  Future<void> _handleDelete(SavedDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete File?'),
        content: Text('Are you sure you want to delete "${doc.title}.pdf"? This cannot be undone.'),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(savedFilesProvider.notifier).delete(doc);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "${doc.title}.pdf"'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleImportFile() async {
    final hasPermission = await StoragePermissionHelper.ensureStoragePermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission is required to import files.')),
        );
      }
      return;
    }

    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (picked == null || picked.path == null) {
        return;
      }

      final file = File(picked.path!);
      const validator = LocalFileValidationService();
      final validation = validator.validateFile(file, allowedExtensions: ['pdf']);

      if (validation is Failure<bool, AppError>) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(validation.error.message),
              backgroundColor: Colors.red.shade700,
            ),
          );
        }
        return;
      }

      final originalName = picked.name;
      final doc = await ref.read(savedFilesProvider.notifier).addExternalFile(
            file,
            customTitle: originalName,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported "${doc.title}.pdf" successfully'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'View',
              onPressed: () => _handleView(doc),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to import file: $e')),
        );
      }
    }
  }

  void _showFileNotFoundSnackBar() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File was deleted or moved from device storage.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = theme.colorScheme.outline;
    final files = ref.watch(savedFilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Files'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () => ref.read(savedFilesProvider.notifier).refresh(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: files.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _handleImportFile,
              icon: const Icon(Icons.add),
              label: const Text('Import PDF'),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: files.isEmpty
              ? _buildEmptyState(context, isDark, borderColor)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: files.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = files[index];
                    return _buildFileCard(context, doc, isDark, borderColor);
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, Color borderColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                border: Border.all(color: borderColor, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.folder_open_outlined, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Saved Files Yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Documents you scan, import, or convert will appear here automatically on your device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _handleImportFile,
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Import from Device'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileCard(
    BuildContext context,
    SavedDocument doc,
    bool isDark,
    Color borderColor,
  ) {
    final formattedDate =
        '${doc.createdAt.year}-${doc.createdAt.month.toString().padLeft(2, '0')}-${doc.createdAt.day.toString().padLeft(2, '0')} ${doc.createdAt.hour.toString().padLeft(2, '0')}:${doc.createdAt.minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111111) : Colors.white,
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _handleView(doc),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        // File icon (PDF or Image)
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF3F3F3),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: doc.filePath.toLowerCase().endsWith('.pdf')
                                  ? const Color(0xFFFF9500).withValues(alpha: 0.4)
                                  : const Color(0xFF007AFF).withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            doc.filePath.toLowerCase().endsWith('.pdf')
                                ? Icons.picture_as_pdf_outlined
                                : Icons.image_outlined,
                            size: 20,
                            color: doc.filePath.toLowerCase().endsWith('.pdf')
                                ? const Color(0xFFFF9500)
                                : const Color(0xFF007AFF),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doc.filePath.toLowerCase().endsWith('.pdf')
                                    ? (doc.title.toLowerCase().endsWith('.pdf') ? doc.title : '${doc.title}.pdf')
                                    : (doc.title.contains('.') ? doc.title : '${doc.title}${doc.filePath.substring(doc.filePath.lastIndexOf('.'))}'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                doc.filePath.toLowerCase().endsWith('.pdf')
                                    ? '${doc.formattedSize} • ${doc.pageCount} ${doc.pageCount == 1 ? 'page' : 'pages'} • $formattedDate'
                                    : '${doc.formattedSize} • ${doc.filePath.split('.').last.toUpperCase()} • $formattedDate',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Overflow popup menu for quick actions
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20),
                tooltip: 'File actions',
                onSelected: (action) {
                  switch (action) {
                    case 'view':
                      _handleView(doc);
                      break;
                    case 'share':
                      _handleShare(doc);
                      break;
                    case 'edit':
                      _handleEdit(doc);
                      break;
                    case 'print':
                      _handlePrint(doc);
                      break;
                    case 'rename':
                      _handleRename(doc);
                      break;
                    case 'delete':
                      _handleDelete(doc);
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: _ActionRow(icon: Icons.visibility_outlined, text: 'View'),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: _ActionRow(icon: Icons.share_outlined, text: 'Share'),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: _ActionRow(icon: Icons.edit_outlined, text: 'Edit'),
                  ),
                  const PopupMenuItem(
                    value: 'print',
                    child: _ActionRow(icon: Icons.print_outlined, text: 'Print'),
                  ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: _ActionRow(icon: Icons.drive_file_rename_outline, text: 'Rename'),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: _ActionRow(
                      icon: Icons.delete_outline,
                      text: 'Delete',
                      isDestructive: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 6),
          // Direct action buttons row for fast 1-tap usage
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _QuickActionButton(
                icon: Icons.visibility_outlined,
                label: 'View',
                onTap: () => _handleView(doc),
              ),
              _QuickActionButton(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: () => _handleShare(doc),
              ),
              _QuickActionButton(
                icon: Icons.edit_outlined,
                label: 'Edit',
                onTap: () => _handleEdit(doc),
              ),
              _QuickActionButton(
                icon: Icons.print_outlined,
                label: 'Print',
                onTap: () => _handlePrint(doc),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDestructive;

  const _ActionRow({
    required this.icon,
    required this.text,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red.shade400 : null;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(text, style: TextStyle(color: color)),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isDark ? Colors.white70 : Colors.black87),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
