import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_limits.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/result/result.dart';
import '../../../core/utils/storage_permission_helper.dart';
import '../../../services/file_validation_service.dart';
import '../../../services/image_conversion_service.dart';
import '../../../services/pdf_compression_service.dart';
import '../../../services/pdf_merge_service.dart';
import '../../../services/pdf_split_service.dart';
import '../../files/data/files_repository.dart';
import '../../files/domain/saved_document.dart';
import '../../home/domain/tool_item.dart';
import 'widgets/pdf_password_dialog.dart';

class ToolFlowScreen extends ConsumerStatefulWidget {
  final String toolId;
  final String? format;
  final int initialStepIndex;
  final String? initialFilePath;

  const ToolFlowScreen({
    super.key,
    required this.toolId,
    this.format,
    this.initialStepIndex = 0,
    this.initialFilePath,
  });

  @override
  ConsumerState<ToolFlowScreen> createState() => _ToolFlowScreenState();
}

class _ToolFlowScreenState extends ConsumerState<ToolFlowScreen> {
  late int _currentStepIndex;

  static const List<String> _steps = [
    'Select files',
    'Options',
    'Progress',
    'Result',
  ];

  // Image conversion flow state
  final ImagePicker _picker = ImagePicker();
  final ImageConversionService _conversionService =
      const ImageConversionService();

  String? _selectedImagePath;
  String _sourceFormat = '';
  int _sourceFileSizeBytes = 0;
  late String _targetFormat;
  int _quality = 92;
  bool _isConverting = false;
  String? _conversionError;
  ConvertedImageResult? _conversionResult;
  bool _isSavedToFiles = false;

  // Compress PDF flow state
  final PdfCompressionService _compressService = const PdfCompressionService();
  PdfCompressionPreset _compressionPreset = PdfCompressionPreset.recommended;
  int _compressQuality = 65;
  bool _isCompressing = false;
  String _compressStage = '';
  double? _compressProgress;
  String? _compressError;
  CompressedPdfResult? _compressResult;
  bool _isCompressedSavedToFiles = false;
  bool _isSavingCompressedPdf = false;

  // Merge PDF state
  final PdfMergeService _mergeService = const PdfMergeService();
  final TextEditingController _mergeOutputNameController =
      TextEditingController(text: 'merged_document');
  bool _isMerging = false;
  String _mergeStage = '';
  double? _mergeProgress;
  String? _mergeError;
  MergedPdfResult? _mergeResult;
  bool _isMergedSavedToFiles = false;
  bool _isSavingMergedPdf = false;

  // Split PDF state
  final PdfSplitService _splitService = const PdfSplitService();
  final TextEditingController _splitPrefixController = TextEditingController();
  final TextEditingController _splitRangesController = TextEditingController();
  final TextEditingController _splitEveryNController =
      TextEditingController(text: '2');
  final TextEditingController _splitPartsController =
      TextEditingController(text: '2');
  SplitMode _splitMode = SplitMode.customRanges;
  int _splitTotalPages = 1;
  bool _splitIsEncrypted = false;
  SplitValidationResult _splitValidation =
      const SplitValidationResult(isValid: false);
  bool _isSplitting = false;
  String _splitStage = '';
  double? _splitProgress;
  String? _splitError;
  SplitPdfResult? _splitResult;
  bool _isSplitSavedToFiles = false;
  bool _isSavingSplitPdf = false;

  // Multi-tool files state
  final List<File> _selectedFiles = [];

  @override
  void dispose() {
    _mergeOutputNameController.dispose();
    _splitPrefixController.dispose();
    _splitRangesController.dispose();
    _splitEveryNController.dispose();
    _splitPartsController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _currentStepIndex = widget.initialStepIndex;
    final requested = widget.format?.trim().toUpperCase();
    if (requested != null &&
        ImageConversionService.supportedOutputFormats.contains(requested)) {
      _targetFormat = requested;
    } else {
      _targetFormat = 'JPG';
    }

    final initialPath = widget.initialFilePath;
    if (initialPath != null && initialPath.isNotEmpty) {
      final file = File(initialPath);
      if (file.existsSync()) {
        if (_isImageConvert) {
          _selectedImagePath = file.path;
          final fileName = file.path
              .split(Platform.pathSeparator)
              .last
              .split('/')
              .last;
          final parts = fileName.split('.');
          _sourceFormat = parts.length > 1 ? parts.last.toUpperCase() : 'JPG';
          _sourceFileSizeBytes = file.lengthSync();
          _currentStepIndex = 1;
        } else {
          _selectedFiles.add(file);
          if (widget.toolId == 'split_pdf') {
            _inspectAndInitSplit(file);
          }
          if (widget.toolId != 'merge_pdf') {
            _currentStepIndex = 1;
          }
        }
      }
    }
  }

  bool get _isImageConvert => widget.toolId == 'image_convert';
  bool get _isCompressPdf => widget.toolId == 'compress_pdf';
  bool get _isMergePdf => widget.toolId == 'merge_pdf';
  bool get _isSplitPdf => widget.toolId == 'split_pdf';

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        requestFullMetadata: true,
      );

      if (picked != null) {
        final file = File(picked.path);
        const validator = LocalFileValidationService();
        final validation = validator.validateFile(
          file,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'],
        );

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

        final size = await file.length();
        final detected = ImageConversionService.detectFormat(picked.path);

        setState(() {
          _selectedImagePath = picked.path;
          _sourceFormat = detected;
          _sourceFileSizeBytes = size;
          _conversionError = null;
          _conversionResult = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _pickImageFromStorage() async {
    final hasPermission =
        await StoragePermissionHelper.ensureStoragePermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to browse images.'),
          ),
        );
      }
      return;
    }

    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'],
      );

      if (picked == null || picked.path == null) return;

      final path = picked.path!;
      final file = File(path);
      const validator = LocalFileValidationService();
      final validation = validator.validateFile(
        file,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'],
      );

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

      final size = await file.length();
      final detected = ImageConversionService.detectFormat(path);

      setState(() {
        _selectedImagePath = path;
        _sourceFormat = detected;
        _sourceFileSizeBytes = size;
        _conversionError = null;
        _conversionResult = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image from storage: $e')),
        );
      }
    }
  }

  Future<void> _pickFilesFromDevice({
    required List<String> allowedExtensions,
    required bool allowMultiple,
  }) async {
    final hasPermission =
        await StoragePermissionHelper.ensureStoragePermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to browse files.'),
          ),
        );
      }
      return;
    }

    try {
      final List<PlatformFile> pickedFiles;
      if (allowMultiple) {
        pickedFiles = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: allowedExtensions,
        );
      } else {
        final single = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: allowedExtensions,
        );
        pickedFiles = single != null ? [single] : [];
      }

      if (pickedFiles.isEmpty) return;

      const validator = LocalFileValidationService();
      final validFiles = <File>[];

      for (final picked in pickedFiles) {
        if (picked.path == null) continue;
        final file = File(picked.path!);
        final validation = validator.validateFile(
          file,
          allowedExtensions: allowedExtensions,
        );

        if (validation is Failure<bool, AppError>) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${picked.name}: ${validation.error.message}'),
                backgroundColor: Colors.red.shade700,
              ),
            );
          }
        } else {
          if (!allowMultiple) {
            validFiles.clear();
            validFiles.add(file);
            break;
          } else {
            if (!_selectedFiles.any((f) => f.path == file.path) &&
                !validFiles.any((f) => f.path == file.path)) {
              validFiles.add(file);
            }
          }
        }
      }

      if (validFiles.isNotEmpty && mounted) {
        if (_isMergePdf) {
          final remainingSlots = 2 - _selectedFiles.length;
          if (remainingSlots <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Merge PDF accepts 2 PDFs at a time. Remove one first.',
                ),
              ),
            );
            return;
          }
          final toAdd = validFiles.take(remainingSlots).toList();
          if (validFiles.length > remainingSlots) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Merge PDF accepts 2 PDFs; extra files ignored.'),
              ),
            );
          }
          setState(() {
            _selectedFiles.addAll(toAdd);
          });
        } else {
          setState(() {
            if (!allowMultiple) {
              _selectedFiles.clear();
            }
            _selectedFiles.addAll(validFiles);
          });
          if (_isSplitPdf && validFiles.isNotEmpty) {
            _inspectAndInitSplit(validFiles.first);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick files: $e')));
      }
    }
  }

  Future<void> _showSavedDocumentsPicker({required bool allowMultiple}) async {
    final savedDocs = ref.read(savedFilesProvider);
    if (!mounted) return;

    if (savedDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No saved documents in KrocPDF yet. Import or scan files first.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (!allowMultiple) {
      final selected = await showModalBottomSheet<SavedDocument>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          final theme = Theme.of(ctx);
          final isDark = theme.brightness == Brightness.dark;
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.85,
            expand: false,
            builder: (context, scrollController) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pick Saved Document',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: savedDocs.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final doc = savedDocs[index];
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: theme.colorScheme.outline,
                              width: 0.8,
                            ),
                          ),
                          leading: const Icon(
                            Icons.picture_as_pdf_outlined,
                            color: Color(0xFFFF9500),
                          ),
                          title: Text(
                            '${doc.title}.pdf',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${doc.formattedSize} • ${doc.pageCount} ${doc.pageCount == 1 ? 'page' : 'pages'}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          onTap: () => Navigator.of(ctx).pop(doc),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      );

      if (selected != null) {
        final file = File(selected.filePath);
        const validator = LocalFileValidationService();
        final validation = validator.validateFile(
          file,
          allowedExtensions: ['pdf'],
        );
        if (validation is Failure<bool, AppError>) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(validation.error.message)));
          }
          return;
        }
        setState(() {
          _selectedFiles.clear();
          _selectedFiles.add(file);
        });
        if (_isSplitPdf) {
          _inspectAndInitSplit(file);
        }
      }
    } else {
      final selectedDocIds = <String>{};
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (ctx) {
          final theme = Theme.of(ctx);
          final isDark = theme.brightness == Brightness.dark;
          return StatefulBuilder(
            builder: (ctx, setModalState) {
              return DraggableScrollableSheet(
                initialChildSize: 0.65,
                minChildSize: 0.4,
                maxChildSize: 0.85,
                expand: false,
                builder: (context, scrollController) {
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Pick Saved Documents to Merge',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.of(ctx).pop(false),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          itemCount: savedDocs.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final doc = savedDocs[index];
                            final isChecked = selectedDocIds.contains(doc.id);
                            return CheckboxListTile(
                              value: isChecked,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: theme.colorScheme.outline,
                                  width: 0.8,
                                ),
                              ),
                              secondary: const Icon(
                                Icons.picture_as_pdf_outlined,
                                color: Color(0xFFFF9500),
                              ),
                              title: Text(
                                '${doc.title}.pdf',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                '${doc.formattedSize} • ${doc.pageCount} ${doc.pageCount == 1 ? 'page' : 'pages'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black54,
                                ),
                              ),
                              onChanged: (val) {
                                setModalState(() {
                                  if (val == true) {
                                    if (_isMergePdf &&
                                        _selectedFiles.length +
                                                selectedDocIds.length >=
                                            2) {
                                      return;
                                    }
                                    selectedDocIds.add(doc.id);
                                  } else {
                                    selectedDocIds.remove(doc.id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: selectedDocIds.isNotEmpty
                                ? () => Navigator.of(ctx).pop(true)
                                : null,
                            child: Text(
                              'Add Selected (${selectedDocIds.length})',
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      );

      if (confirmed == true && selectedDocIds.isNotEmpty) {
        const validator = LocalFileValidationService();
        final newlyAdded = <File>[];
        for (final id in selectedDocIds) {
          final doc = savedDocs.firstWhere((d) => d.id == id);
          final file = File(doc.filePath);
          final valResult = validator.validateFile(
            file,
            allowedExtensions: ['pdf'],
          );
          if (valResult is Success) {
            if (!_selectedFiles.any((f) => f.path == file.path)) {
              newlyAdded.add(file);
            }
          }
        }
        setState(() {
          _selectedFiles.addAll(newlyAdded);
        });
      }
    }
  }

  Future<void> _startConversion() async {
    if (_selectedImagePath == null) return;

    setState(() {
      _currentStepIndex = 2;
      _isConverting = true;
      _conversionError = null;
    });

    try {
      final result = await _conversionService.convertImage(
        inputPath: _selectedImagePath!,
        targetFormat: _targetFormat,
        quality: _quality,
      );

      if (mounted) {
        setState(() {
          _conversionResult = result;
          _isConverting = false;
          _currentStepIndex = 3;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _conversionError = e.toString();
          _isConverting = false;
        });
      }
    }
  }

  Future<void> _handleShareResult() async {
    if (_conversionResult == null) return;
    final file = File(_conversionResult!.outputPath);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Converted file not found on disk.')),
        );
      }
      return;
    }
    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(_conversionResult!.outputPath)]);
  }

  Future<void> _handleDownloadResult() async {
    if (_conversionResult == null || _isSavedToFiles) return;
    final file = File(_conversionResult!.outputPath);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Converted file not found on disk.')),
        );
      }
      return;
    }

    try {
      await ref
          .read(savedFilesProvider.notifier)
          .addExternalFile(
            file,
            customTitle: _conversionResult!.fileName,
            sourceType: SavedDocumentSource.convert,
          );

      if (mounted) {
        setState(() {
          _isSavedToFiles = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "${_conversionResult!.fileName}" to Files.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save file: $e')));
      }
    }
  }

  Future<void> _startCompression() async {
    if (_selectedFiles.isEmpty) return;
    final file = _selectedFiles.first;
    if (!file.existsSync()) {
      setState(() {
        _currentStepIndex = 2;
        _isCompressing = false;
        _compressError = 'Selected PDF file no longer exists on disk.';
      });
      return;
    }

    setState(() {
      _currentStepIndex = 2;
      _isCompressing = true;
      _compressError = null;
      _compressResult = null;
      _compressStage = 'Analyzing PDF structure...';
      _compressProgress = 0.1;
      _isCompressedSavedToFiles = false;
    });

    try {
      final result = await _compressService.compressPdf(
        inputPath: file.path,
        quality: _compressQuality,
        onProgress: (status, progress) {
          if (mounted) {
            setState(() {
              _compressStage = status;
              _compressProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _compressResult = result;
          _isCompressing = false;
          _currentStepIndex = 3;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _compressError = e.toString();
          _isCompressing = false;
        });
      }
    }
  }

  Future<void> _handleShareCompressedPdf() async {
    if (_compressResult == null) return;
    final file = File(_compressResult!.outputPath);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compressed PDF file not found on disk.'),
          ),
        );
      }
      return;
    }
    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(_compressResult!.outputPath)]);
  }

  Future<void> _handleDownloadCompressedPdf() async {
    if (_compressResult == null ||
        _isCompressedSavedToFiles ||
        _isSavingCompressedPdf) {
      return;
    }
    _isSavingCompressedPdf = true;
    try {
      final file = File(_compressResult!.outputPath);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Compressed PDF file not found on disk.'),
            ),
          );
        }
        return;
      }

      await ref
          .read(savedFilesProvider.notifier)
          .addExternalFile(
            file,
            customTitle: _compressResult!.fileName,
            sourceType: SavedDocumentSource.compress,
          );

      if (mounted) {
        setState(() {
          _isCompressedSavedToFiles = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "${_compressResult!.fileName}" to Files.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save file: $e')));
      }
    } finally {
      _isSavingCompressedPdf = false;
    }
  }

  void _resetFlow() {
    setState(() {
      _currentStepIndex = 0;
      _selectedImagePath = null;
      _sourceFormat = '';
      _sourceFileSizeBytes = 0;
      _conversionError = null;
      _conversionResult = null;
      _isConverting = false;
      _isSavedToFiles = false;

      _compressQuality = 65;
      _compressionPreset = PdfCompressionPreset.recommended;
      _isCompressing = false;
      _compressStage = '';
      _compressProgress = null;
      _compressError = null;
      _compressResult = null;
      _isCompressedSavedToFiles = false;

      _mergeOutputNameController.text = 'merged_document';
      _isMerging = false;
      _mergeStage = '';
      _mergeProgress = null;
      _mergeError = null;
      _mergeResult = null;
      _isMergedSavedToFiles = false;

      _splitPrefixController.clear();
      _splitRangesController.clear();
      _splitEveryNController.text = '2';
      _splitPartsController.text = '2';
      _splitMode = SplitMode.customRanges;
      _splitTotalPages = 1;
      _splitIsEncrypted = false;
      _splitValidation = const SplitValidationResult(isValid: false);
      _isSplitting = false;
      _splitStage = '';
      _splitProgress = null;
      _splitError = null;
      _splitResult = null;
      _isSplitSavedToFiles = false;
      _isSavingSplitPdf = false;

      _selectedFiles.clear();
    });
  }

  Future<void> _startMerge() async {
    if (_selectedFiles.length != 2) return;
    final paths = _selectedFiles.map((f) => f.path).toList();

    for (final file in _selectedFiles) {
      if (!file.existsSync()) {
        setState(() {
          _currentStepIndex = 2;
          _isMerging = false;
          _mergeError = 'Selected PDF file no longer exists on disk.';
        });
        return;
      }
    }

    setState(() {
      _currentStepIndex = 2;
      _isMerging = true;
      _mergeError = null;
      _mergeResult = null;
      _mergeStage = 'Checking PDF files...';
      _mergeProgress = 0.1;
      _isMergedSavedToFiles = false;
    });

    try {
      final inspection = await _mergeService.inspectFiles(paths);
      if (!mounted) return;

      if (inspection.hasInvalidFiles) {
        setState(() {
          _mergeError = inspection.invalidFiles.values.first;
          _isMerging = false;
        });
        return;
      }

      var passwords = <String, String>{};
      if (inspection.hasEncryptedFiles) {
        final entered = await showPdfPasswordDialog(
          context: context,
          encryptedFilePaths: inspection.encryptedFilePaths,
        );
        if (!mounted) return;
        if (entered == null) {
          setState(() {
            _isMerging = false;
            _currentStepIndex = 1;
          });
          return;
        }
        passwords = entered;
      }

      while (true) {
        try {
          final result = await _mergeService.mergePdfs(
            inputPaths: paths,
            passwords: passwords,
            outputFileName: _mergeOutputNameController.text,
            onProgress: (status, progress) {
              if (mounted) {
                setState(() {
                  _mergeStage = status;
                  _mergeProgress = progress;
                });
              }
            },
          );
          if (!mounted) return;
          setState(() {
            _mergeResult = result;
            _isMerging = false;
            _currentStepIndex = 3;
          });
          return;
        } on PdfInvalidPasswordException catch (e) {
          if (!mounted) return;
          final retried = await showPdfPasswordDialog(
            context: context,
            encryptedFilePaths: e.failedFilePaths,
            initialPasswords: passwords,
            fileErrors: {
              for (final p in e.failedFilePaths) p: 'Incorrect password',
            },
          );
          if (!mounted) return;
          if (retried == null) {
            setState(() {
              _isMerging = false;
              _currentStepIndex = 1;
            });
            return;
          }
          passwords = {...passwords, ...retried};
        } on PdfPasswordRequiredException catch (e) {
          if (!mounted) return;
          final entered = await showPdfPasswordDialog(
            context: context,
            encryptedFilePaths: e.encryptedFilePaths,
            initialPasswords: passwords,
          );
          if (!mounted) return;
          if (entered == null) {
            setState(() {
              _isMerging = false;
              _currentStepIndex = 1;
            });
            return;
          }
          passwords = {...passwords, ...entered};
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mergeError = e.toString();
          _isMerging = false;
        });
      }
    }
  }

  Future<void> _handleShareMergedPdf() async {
    if (_mergeResult == null) return;
    final file = File(_mergeResult!.outputPath);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Merged PDF file not found on disk.')),
        );
      }
      return;
    }
    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(_mergeResult!.outputPath)]);
  }

  Future<void> _handleDownloadMergedPdf() async {
    if (_mergeResult == null || _isMergedSavedToFiles || _isSavingMergedPdf) {
      return;
    }
    _isSavingMergedPdf = true;
    try {
      final file = File(_mergeResult!.outputPath);
      if (!await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Merged PDF file not found on disk.')),
          );
        }
        return;
      }

      await ref
          .read(savedFilesProvider.notifier)
          .addExternalFile(
            file,
            customTitle: _mergeResult!.fileName,
            sourceType: SavedDocumentSource.merge,
          );

      if (mounted) {
        setState(() {
          _isMergedSavedToFiles = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved "${_mergeResult!.fileName}" to Files.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save file: $e')));
      }
    } finally {
      _isSavingMergedPdf = false;
    }
  }

  Future<void> _inspectAndInitSplit(File file) async {
    try {
      final inspection = await _splitService.inspectPdf(file.path);
      final rawName = file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : 'document.pdf';
      final dotIdx = rawName.lastIndexOf('.');
      final baseName = dotIdx > 0 ? rawName.substring(0, dotIdx) : rawName;

      if (mounted) {
        setState(() {
          _splitTotalPages =
              inspection.pageCount > 0 ? inspection.pageCount : 1;
          _splitIsEncrypted = inspection.isEncrypted;
          if (_splitPrefixController.text.isEmpty) {
            _splitPrefixController.text = baseName;
          }
          if (_splitRangesController.text.isEmpty) {
            _splitRangesController.text = '1-$_splitTotalPages';
          }
          _splitError = null;
        });
        _updateSplitValidation();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _splitError = 'Failed to inspect PDF: $e';
        });
      }
    }
  }

  void _updateSplitValidation() {
    setState(() {
      switch (_splitMode) {
        case SplitMode.customRanges:
          _splitValidation = SplitRangeValidator.validateRanges(
            _splitRangesController.text,
            _splitTotalPages,
          );
          break;
        case SplitMode.everyNPages:
          final n = int.tryParse(_splitEveryNController.text.trim()) ?? 1;
          _splitValidation = SplitRangeValidator.validateEveryNPages(
            n,
            _splitTotalPages,
          );
          break;
        case SplitMode.extractAllPages:
          _splitValidation = SplitRangeValidator.validateExtractAllPages(
            _splitTotalPages,
          );
          break;
        case SplitMode.splitIntoNParts:
          final parts = int.tryParse(_splitPartsController.text.trim()) ?? 2;
          _splitValidation = SplitRangeValidator.validateSplitIntoNParts(
            parts,
            _splitTotalPages,
          );
          break;
      }
    });
  }

  Future<void> _promptOrStartSplit() async {
    if (!_splitValidation.isValid || _selectedFiles.isEmpty) return;

    // 1. Check for 15+ files warning
    if (_splitValidation.fileCount >= 15) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('High File Count'),
          content: Text(
            'This split will create ${_splitValidation.fileCount} separate PDF files.\n\nAre you sure you want to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Proceed'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      if (!mounted) return;
    }

    // 2. Check for gap confirmation (> 2 omitted pages in customRanges)
    if (_splitMode == SplitMode.customRanges &&
        _splitValidation.hasSignificantGap &&
        _splitValidation.omittedRangesSummary != null) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Omitted Pages Detected'),
          content: Text(
            'Pages ${_splitValidation.omittedRangesSummary} won\'t be included in any output file.\n\nDo you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      if (!mounted) return;
    }

    _startSplit();
  }

  Future<void> _startSplit() async {
    if (_selectedFiles.isEmpty || _isSplitting) return;

    final file = _selectedFiles.first;
    if (!await file.exists()) {
      setState(() {
        _splitError = 'Selected PDF file no longer exists on disk.';
      });
      return;
    }

    setState(() {
      _isSplitting = true;
      _splitStage = 'Preparing split...';
      _splitProgress = 0.05;
      _splitError = null;
      _splitResult = null;
      _isSplitSavedToFiles = false;
      _currentStepIndex = 2;
    });

    try {
      final groups = _splitValidation.groups;
      final prefix = _splitPrefixController.text.trim();

      final result = await _splitService.splitPdf(
        inputPath: file.path,
        groups: groups,
        outputPrefix: prefix.isNotEmpty ? prefix : null,
        onProgress: (status, progress) {
          if (mounted) {
            setState(() {
              _splitStage = status;
              _splitProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _splitResult = result;
          _isSplitting = false;
          _currentStepIndex = 3;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _splitError = e.toString();
          _isSplitting = false;
        });
      }
    }
  }

  Future<void> _handleSaveAllSplitPdfs() async {
    if (_splitResult == null || _isSplitSavedToFiles || _isSavingSplitPdf) {
      return;
    }
    setState(() => _isSavingSplitPdf = true);

    try {
      int savedCount = 0;
      for (final out in _splitResult!.outputFiles) {
        final f = File(out.outputPath);
        if (await f.exists()) {
          await ref.read(savedFilesProvider.notifier).addExternalFile(
            f,
            customTitle: out.fileName,
            sourceType: SavedDocumentSource.split,
          );
          savedCount++;
        }
      }

      if (mounted) {
        setState(() {
          _isSplitSavedToFiles = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved $savedCount PDF files to Saved Documents.'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save split files: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingSplitPdf = false);
      }
    }
  }

  Future<void> _handleShareAllSplitPdfs() async {
    if (_splitResult == null || _splitResult!.outputFiles.isEmpty) return;
    final xfiles =
        _splitResult!.outputFiles.map((f) => XFile(f.outputPath)).toList();
    // ignore: deprecated_member_use
    await Share.shareXFiles(xfiles);
  }

  @override
  Widget build(BuildContext context) {
    final tool = ToolItem.findById(widget.toolId);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = theme.colorScheme.outline;

    final toolTitle = tool?.title ?? 'Tool Flow';
    final formatLabel = widget.format != null
        ? ' (${widget.format!.toUpperCase()})'
        : '';

    final bool canGoNext;
    if (_isImageConvert) {
      canGoNext =
          (_currentStepIndex == 0 && _selectedImagePath != null) ||
          (_currentStepIndex == 1);
    } else if (_isCompressPdf) {
      canGoNext =
          (_currentStepIndex == 0 && _selectedFiles.isNotEmpty) ||
          (_currentStepIndex == 1);
    } else if (_isSplitPdf) {
      canGoNext =
          (_currentStepIndex == 0 && _selectedFiles.isNotEmpty) ||
          (_currentStepIndex == 1 && _splitValidation.isValid && !_isSplitting);
    } else if (widget.toolId == 'office_to_pdf') {
      // Office to PDF is UI scaffolding only in this phase
      canGoNext = false;
    } else if (widget.toolId == 'merge_pdf') {
      canGoNext =
          (_currentStepIndex == 0 && _selectedFiles.length == 2) ||
          (_currentStepIndex == 1);
    } else {
      canGoNext =
          (_currentStepIndex == 0 && _selectedFiles.isNotEmpty) ||
          (_currentStepIndex > 0);
    }

    return Scaffold(
      appBar: AppBar(title: Text('$toolTitle$formatLabel')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            children: [
              // Step Indicator Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: borderColor, width: 1),
                  ),
                ),
                child: Row(
                  children: List.generate(_steps.length, (index) {
                    final isCurrent = index == _currentStepIndex;
                    final isDone = index < _currentStepIndex;

                    return Expanded(
                      child: InkWell(
                        onTap: () {
                          if (_isConverting || _isCompressing || _isMerging || _isSplitting) return;
                          if (_isImageConvert) {
                            if (index == 0) {
                              setState(() => _currentStepIndex = index);
                            } else if (index == 1 &&
                                _selectedImagePath != null) {
                              setState(() => _currentStepIndex = index);
                            } else if (index == 2 &&
                                _selectedImagePath != null) {
                              _startConversion();
                            } else if (index == 3 &&
                                _conversionResult != null) {
                              setState(() => _currentStepIndex = index);
                            }
                          } else if (_isCompressPdf) {
                            if (index == 0) {
                              setState(() => _currentStepIndex = index);
                            } else if (index == 1 &&
                                _selectedFiles.isNotEmpty) {
                              setState(() => _currentStepIndex = index);
                            } else if (index == 2 &&
                                _selectedFiles.isNotEmpty) {
                              _startCompression();
                            } else if (index == 3 && _compressResult != null) {
                              setState(() => _currentStepIndex = index);
                            }
                          } else if (_isMergePdf) {
                            if (index == 0) {
                              setState(() => _currentStepIndex = index);
                            } else if (index == 1 &&
                                _selectedFiles.length == 2) {
                              setState(() => _currentStepIndex = index);
                            } else if (index == 2 &&
                                _selectedFiles.length == 2) {
                              _startMerge();
                            } else if (index == 3 && _mergeResult != null) {
                              setState(() => _currentStepIndex = index);
                            }
                          } else if (_isSplitPdf) {
                            if (index == 0) {
                              setState(() => _currentStepIndex = index);
                            } else if (index == 1 &&
                                _selectedFiles.isNotEmpty) {
                              setState(() => _currentStepIndex = index);
                            } else if (index == 2 &&
                                _selectedFiles.isNotEmpty &&
                                _splitValidation.isValid) {
                              _promptOrStartSplit();
                            } else if (index == 3 && _splitResult != null) {
                              setState(() => _currentStepIndex = index);
                            }
                          } else {
                            if (index == 0) {
                              setState(() => _currentStepIndex = index);
                            } else if (canGoNext) {
                              setState(() => _currentStepIndex = index);
                            }
                          }
                        },
                        child: Column(
                          children: [
                            Text(
                              _steps[index],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isCurrent
                                    ? (isDark ? Colors.white : Colors.black)
                                    : (isDark
                                          ? Colors.white38
                                          : Colors.black38),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 2,
                              color: isCurrent || isDone
                                  ? (isDark ? Colors.white : Colors.black)
                                  : borderColor,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Active Step View
              Expanded(
                child: Padding(
                  padding: _isSplitPdf && _currentStepIndex == 3
                      ? const EdgeInsets.fromLTRB(16, 12, 16, 0)
                      : const EdgeInsets.all(20),
                  child: _isSplitPdf && _currentStepIndex == 3
                      ? _buildSplitPdfResultStep(context, borderColor, isDark)
                      : Center(
                          child: SingleChildScrollView(
                            child: _buildStepContent(context, borderColor, isDark),
                          ),
                        ),
                ),
              ),

              // Step Navigation Bar
              if (!(_isSplitPdf && _currentStepIndex == 3))
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: borderColor, width: 1)),
                  ),
                  child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStepIndex > 0 &&
                        !_isConverting &&
                        !_isCompressing &&
                        !_isMerging &&
                        !_isSplitting)
                      OutlinedButton(
                        onPressed: () => setState(() => _currentStepIndex--),
                        child: const Text('Back'),
                      )
                    else
                      const SizedBox.shrink(),
                    if (_currentStepIndex < _steps.length - 1)
                      ElevatedButton(
                        onPressed: canGoNext
                            ? () {
                                if (_isImageConvert && _currentStepIndex == 1) {
                                  _startConversion();
                                } else if (_isCompressPdf &&
                                    _currentStepIndex == 1) {
                                  _startCompression();
                                } else if (_isMergePdf &&
                                    _currentStepIndex == 1) {
                                  _startMerge();
                                } else if (_isSplitPdf &&
                                    _currentStepIndex == 1) {
                                  _promptOrStartSplit();
                                } else {
                                  setState(() {
                                    _currentStepIndex++;
                                    if (_isSplitPdf &&
                                        _currentStepIndex == 1 &&
                                        _selectedFiles.isNotEmpty) {
                                      _inspectAndInitSplit(_selectedFiles.first);
                                    }
                                  });
                                }
                              }
                            : null,
                        child: Text(
                          _isImageConvert && _currentStepIndex == 1
                              ? 'Convert to $_targetFormat'
                              : _isCompressPdf && _currentStepIndex == 1
                              ? 'Compress PDF'
                              : _isMergePdf && _currentStepIndex == 1
                              ? 'Merge PDF'
                              : _isSplitPdf && _currentStepIndex == 1
                              ? 'Split PDF'
                              : 'Next step',
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: _resetFlow,
                        child: Text(
                          _isCompressPdf
                              ? 'Compress another'
                              : _isMergePdf
                              ? 'Merge another'
                              : _isSplitPdf
                              ? 'Split another'
                              : 'Convert another',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(
    BuildContext context,
    Color borderColor,
    bool isDark,
  ) {
    if (_isImageConvert) {
      switch (_currentStepIndex) {
        case 0:
          return _buildImageConvertSelectStep(context, borderColor, isDark);
        case 1:
          return _buildImageConvertOptionsStep(context, borderColor, isDark);
        case 2:
          return _buildImageConvertProgressStep(context, borderColor, isDark);
        case 3:
          return _buildImageConvertResultStep(context, borderColor, isDark);
        default:
          return const SizedBox.shrink();
      }
    }

    if (_isCompressPdf) {
      switch (_currentStepIndex) {
        case 0:
          return _buildSelectFilesStep(context, borderColor, isDark);
        case 1:
          return _buildCompressPdfOptionsStep(context, borderColor, isDark);
        case 2:
          return _buildCompressPdfProgressStep(context, borderColor, isDark);
        case 3:
          return _buildCompressPdfResultStep(context, borderColor, isDark);
        default:
          return const SizedBox.shrink();
      }
    }

    if (_isMergePdf) {
      switch (_currentStepIndex) {
        case 0:
          return _buildSelectFilesStep(context, borderColor, isDark);
        case 1:
          return _buildMergePdfOptionsStep(context, borderColor, isDark);
        case 2:
          return _buildMergePdfProgressStep(context, borderColor, isDark);
        case 3:
          return _buildMergePdfResultStep(context, borderColor, isDark);
        default:
          return const SizedBox.shrink();
      }
    }

    if (_isSplitPdf) {
      switch (_currentStepIndex) {
        case 0:
          return _buildSelectFilesStep(context, borderColor, isDark);
        case 1:
          return _buildSplitPdfOptionsStep(context, borderColor, isDark);
        case 2:
          return _buildSplitPdfProgressStep(context, borderColor, isDark);
        case 3:
          return _buildSplitPdfResultStep(context, borderColor, isDark);
        default:
          return const SizedBox.shrink();
      }
    }

    switch (_currentStepIndex) {
      case 0:
        return _buildSelectFilesStep(context, borderColor, isDark);
      case 1:
        return _buildOptionsStep(context, borderColor, isDark);
      case 2:
        return _buildProgressStep(context, borderColor, isDark);
      case 3:
        return _buildResultStep(context, borderColor, isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  // --- Image Convert Specific Steps ---

  Widget _buildImageConvertSelectStep(
    BuildContext context,
    Color borderColor,
    bool isDark,
  ) {
    if (_selectedImagePath != null) {
      final fileName = _selectedImagePath!
          .split(Platform.pathSeparator)
          .last
          .split('/')
          .last;
      final isHeic = ImageConversionService.isHeic(_selectedImagePath!);

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414) : const Color(0xFFFBFBFB),
              border: Border.all(color: borderColor, width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                if (!isHeic && File(_selectedImagePath!).existsSync())
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 180,
                        maxWidth: 260,
                      ),
                      child: Image.file(
                        File(_selectedImagePath!),
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF222222)
                          : const Color(0xFFEEEEEE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isHeic ? const Color(0xFFFF9500) : borderColor,
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.image_outlined,
                      size: 36,
                      color: isHeic ? const Color(0xFFFF9500) : null,
                    ),
                  ),
                const SizedBox(height: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isHeic
                            ? const Color(0xFFFF9500).withValues(alpha: 0.2)
                            : (isDark ? Colors.white12 : Colors.black12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _sourceFormat,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isHeic ? const Color(0xFFFF9500) : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${(_sourceFileSizeBytes / 1024).toStringAsFixed(1)} KB',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: const Text('Change photo'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => setState(() => _currentStepIndex = 1),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('Choose format'),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.photo_library_outlined, size: 32),
        ),
        const SizedBox(height: 16),
        const Text(
          'Select Image to Convert',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Supports HEIC, JPG, PNG, and WEBP',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_outlined, size: 18),
              label: const Text('Select from Gallery'),
            ),
            OutlinedButton.icon(
              onPressed: _pickImageFromStorage,
              icon: const Icon(Icons.folder_open_outlined, size: 18),
              label: const Text('Browse Storage'),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Take Photo'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageConvertOptionsStep(
    BuildContext context,
    Color borderColor,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141414) : const Color(0xFFF9F9F9),
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 20,
                color: Colors.green,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Input Image Ready',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Detected source format: $_sourceFormat • ${(_sourceFileSizeBytes / 1024).toStringAsFixed(1)} KB',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Target Output Format',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Select the format you would like to convert this image into:',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: ImageConversionService.supportedOutputFormats.map((fmt) {
            final isSelected = _targetFormat == fmt;
            return ChoiceChip(
              label: Text(
                fmt,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.black : Colors.white)
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
              selected: isSelected,
              selectedColor: isDark ? Colors.white : Colors.black,
              backgroundColor: isDark
                  ? const Color(0xFF1E1E1E)
                  : const Color(0xFFF0F0F0),
              side: BorderSide(
                color: isSelected ? Colors.transparent : borderColor,
                width: 1,
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() => _targetFormat = fmt);
                }
              },
            );
          }).toList(),
        ),
        if (_targetFormat == 'PNG' || _targetFormat == 'WEBP') ...[
          const SizedBox(height: 10),
          Text(
            _targetFormat == 'PNG'
                ? 'PNG is lossless — output may be larger than the original file.'
                : 'WEBP output may be larger than the original file.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
        const SizedBox(height: 24),
        if (_targetFormat != 'PNG') ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Compression Quality',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                '$_quality%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
          Slider(
            value: _quality.toDouble(),
            min: 50,
            max: 100,
            divisions: 10,
            label: '$_quality%',
            onChanged: (val) => setState(() => _quality = val.toInt()),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161616) : const Color(0xFFF4F4F4),
            border: Border.all(color: borderColor, width: 0.8),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            _sourceFormat == 'HEIC'
                ? 'Converting HEIC with hardware-accelerated platform decoding for maximum fidelity.'
                : 'Converting image to $_targetFormat entirely on-device (100% confidential).',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageConvertProgressStep(
    BuildContext context,
    Color borderColor,
    bool isDark,
  ) {
    if (_conversionError != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 44, color: Colors.redAccent),
          const SizedBox(height: 14),
          const Text(
            'Conversion Failed',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _conversionError!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _currentStepIndex = 1),
                child: const Text('Back to options'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _startConversion,
                child: const Text('Retry'),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(
          color: isDark ? Colors.white : Colors.black,
          strokeWidth: 2.5,
        ),
        const SizedBox(height: 20),
        Text(
          'Converting $_sourceFormat to $_targetFormat...',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Processing image locally on your device.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildImageConvertResultStep(
    BuildContext context,
    Color borderColor,
    bool isDark,
  ) {
    final res = _conversionResult;
    if (res == null) {
      return const Center(child: Text('No result available.'));
    }

    final isPreviewable =
        res.format != 'HEIC' && File(res.outputPath).existsSync();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 30, color: Colors.green),
        ),
        const SizedBox(height: 14),
        const Text(
          'Conversion Completed!',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Successfully converted to ${res.format}',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141414) : const Color(0xFFFAFAFA),
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              if (isPreviewable)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 180,
                      maxWidth: 260,
                    ),
                    child: Image.file(
                      File(res.outputPath),
                      fit: BoxFit.contain,
                    ),
                  ),
                )
              else
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF222222)
                        : const Color(0xFFECECEC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.insert_drive_file_outlined, size: 32),
                ),
              const SizedBox(height: 14),
              Text(
                res.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Size: ${res.formattedSize} (Original: ${res.formattedOriginalSize})',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _isSavedToFiles ? null : _handleDownloadResult,
              icon: Icon(
                _isSavedToFiles ? Icons.check : Icons.download_outlined,
                size: 18,
              ),
              label: Text(_isSavedToFiles ? 'Saved to Files' : 'Download'),
            ),
            ElevatedButton.icon(
              onPressed: _handleShareResult,
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text('Share File'),
            ),
            OutlinedButton.icon(
              onPressed: _resetFlow,
              icon: const Icon(Icons.refresh_outlined, size: 18),
              label: const Text('Convert Another'),
            ),
          ],
        ),
      ],
    );
  }

  // --- Step 0 Dispatcher for Non-Image-Convert Tools ---

  Widget _buildSelectFilesStep(
    BuildContext context,
    Color borderColor,
    bool isDark,
  ) {
    if (widget.toolId == 'office_to_pdf') {
      return _buildOfficeSelectStep(context, borderColor, isDark);
    } else if (widget.toolId == 'merge_pdf') {
      return _buildMergePdfSelectStep(context, borderColor, isDark);
    } else if (widget.toolId == 'split_pdf') {
      return _buildSinglePdfSelectStep(
        context,
        borderColor,
        isDark,
        title: 'Select PDF to Split',
        subtitle: 'Separate pages or extract ranges from a PDF document',
        icon: Icons.call_split_outlined,
      );
    } else if (widget.toolId == 'compress_pdf') {
      return _buildSinglePdfSelectStep(
        context,
        borderColor,
        isDark,
        title: 'Select PDF to Compress',
        subtitle: 'Reduce PDF file size on-device without quality loss',
        icon: Icons.compress_outlined,
      );
    } else if (widget.toolId == 'image_to_pdf') {
      return _buildImageToPdfSelectStep(context, borderColor, isDark);
    }

    return _buildGenericSelectStep(context, borderColor, isDark);
  }

  // --- Office to PDF Step 0 UI Scaffolding ---

  Widget _buildOfficeSelectStep(
    BuildContext context,
    Color borderColor,
    bool isDark,
  ) {
    if (_selectedFiles.isNotEmpty) {
      final file = _selectedFiles.first;
      final fileName = file.uri.pathSegments.last;
      final size = file.existsSync() ? file.lengthSync() : 0;
      final ext = fileName.contains('.')
          ? fileName.split('.').last.toUpperCase()
          : 'DOC';

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414) : const Color(0xFFFBFBFB),
              border: Border.all(color: borderColor, width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: Colors.blueAccent,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ext,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${(size / 1024).toStringAsFixed(1)} KB',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
              border: Border.all(color: borderColor, width: 0.8),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_outlined,
                  size: 20,
                  color: Colors.blueAccent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Office conversion is cloud-only and will be available when Non-Confidential mode is released.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickFilesFromDevice(
                  allowedExtensions: [
                    'doc',
                    'docx',
                    'xls',
                    'xlsx',
                    'ppt',
                    'pptx',
                  ],
                  allowMultiple: false,
                ),
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: const Text('Change file'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => setState(() => _selectedFiles.clear()),
                child: const Text('Clear'),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.description_outlined, size: 32),
        ),
        const SizedBox(height: 16),
        const Text(
          'Select Office Document',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Supports Word (.doc, .docx), Excel (.xls, .xlsx), PowerPoint (.ppt, .pptx)',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Max ${AppLimits.formattedLimitMb} per file • Cloud conversion',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => _pickFilesFromDevice(
            allowedExtensions: ['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'],
            allowMultiple: false,
          ),
          icon: const Icon(Icons.folder_open_outlined, size: 18),
          label: const Text('Browse Device Storage'),
        ),
      ],
    );
  }

  // --- Merge PDF Step 0 ---

  Widget _buildMergePdfSelectStep(
    BuildContext context,
    Color borderColor,
    bool isDark,
  ) {
    if (_selectedFiles.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_selectedFiles.length} of 2 PDFs selected',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_selectedFiles.length < 2)
                const Text(
                  'Select 2 PDFs',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      final first = _selectedFiles[0];
                      _selectedFiles[0] = _selectedFiles[1];
                      _selectedFiles[1] = first;
                    });
                  },
                  icon: const Icon(Icons.swap_vert, size: 16),
                  label: const Text('Swap Order'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedFiles.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final file = _selectedFiles[index];
              final name = file.uri.pathSegments.last;
              final size = file.existsSync() ? file.lengthSync() : 0;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF141414)
                      : const Color(0xFFFAFAFA),
                  border: Border.all(color: borderColor, width: 0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: isDark ? Colors.white12 : Colors.black12,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 20,
                      color: Color(0xFFFF9500),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${(size / 1024).toStringAsFixed(1)} KB',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () =>
                          setState(() => _selectedFiles.removeAt(index)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          if (_selectedFiles.length < 2)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickFilesFromDevice(
                    allowedExtensions: ['pdf'],
                    allowMultiple: true,
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add from Device'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _showSavedDocumentsPicker(allowMultiple: true),
                  icon: const Icon(Icons.bookmark_border_outlined, size: 16),
                  label: const Text('Add from Saved Documents'),
                ),
              ],
            ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.call_merge_outlined, size: 32),
        ),
        const SizedBox(height: 16),
        const Text(
          'Select PDFs to Merge',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Combine two or more PDF files into a single document.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Max ${AppLimits.formattedLimitMb} per file • 100% on-device',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => _pickFilesFromDevice(
                allowedExtensions: ['pdf'],
                allowMultiple: true,
              ),
              icon: const Icon(Icons.folder_open_outlined, size: 18),
              label: const Text('Browse Device Storage'),
            ),
            OutlinedButton.icon(
              onPressed: () => _showSavedDocumentsPicker(allowMultiple: true),
              icon: const Icon(Icons.bookmark_border_outlined, size: 18),
              label: const Text('Pick from Saved Documents'),
            ),
          ],
        ),
      ],
    );
  }

  // --- Single PDF Step 0 (Split & Compress) ---

  Widget _buildSinglePdfSelectStep(
    BuildContext context,
    Color borderColor,
    bool isDark, {
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    if (_selectedFiles.isNotEmpty) {
      final file = _selectedFiles.first;
      final name = file.uri.pathSegments.last;
      final size = file.existsSync() ? file.lengthSync() : 0;

      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414) : const Color(0xFFFBFBFB),
              border: Border.all(color: borderColor, width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_outlined,
                    color: Color(0xFFFF9500),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(size / 1024).toStringAsFixed(1)} KB',
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
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickFilesFromDevice(
                  allowedExtensions: ['pdf'],
                  allowMultiple: false,
                ),
                icon: const Icon(Icons.swap_horiz, size: 16),
                label: const Text('Change from Device'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    _showSavedDocumentsPicker(allowMultiple: false),
                icon: const Icon(Icons.bookmark_border_outlined, size: 16),
                label: const Text('Pick Saved Document'),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Max ${AppLimits.formattedLimitMb} • 100% on-device',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => _pickFilesFromDevice(
                allowedExtensions: ['pdf'],
                allowMultiple: false,
              ),
              icon: const Icon(Icons.folder_open_outlined, size: 18),
              label: const Text('Browse Device Storage'),
            ),
            OutlinedButton.icon(
              onPressed: () => _showSavedDocumentsPicker(allowMultiple: false),
              icon: const Icon(Icons.bookmark_border_outlined, size: 18),
              label: const Text('Pick from Saved Documents'),
            ),
          ],
        ),
      ],
    );
  }

  // --- Image to PDF Step 0 ---

  Widget _buildImageToPdfSelectStep(
    BuildContext context,
    Color borderColor,
    bool isDark,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.photo_library_outlined, size: 32),
        ),
        const SizedBox(height: 16),
        const Text(
          'Turn Images into PDF',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Import photos or open the Document Page Editor to assemble pages.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => context.push('/edit-document'),
              icon: const Icon(Icons.edit_document, size: 18),
              label: const Text('Open Page Editor'),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickFilesFromDevice(
                allowedExtensions: [
                  'jpg',
                  'jpeg',
                  'png',
                  'webp',
                  'heic',
                  'heif',
                ],
                allowMultiple: true,
              ),
              icon: const Icon(Icons.folder_open_outlined, size: 18),
              label: const Text('Browse Storage'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenericSelectStep(
    BuildContext context,
    Color borderColor,
    bool isDark,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.file_upload_outlined, size: 30),
        ),
        const SizedBox(height: 16),
        const Text(
          'Choose files',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Max ${AppLimits.formattedLimitMb} per file',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => _pickFilesFromDevice(
            allowedExtensions: ['pdf'],
            allowMultiple: false,
          ),
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('Browse Device Storage'),
        ),
      ],
    );
  }

  Widget _buildOptionsStep(
    BuildContext context,
    Color borderColor,
    bool isDark,
  ) {
    return _buildPlaceholder(
      title: 'Options',
      subtitle: 'Options configuration ready.',
      icon: Icons.tune_outlined,
      borderColor: borderColor,
      isDark: isDark,
    );
  }

  Widget _buildProgressStep(
    BuildContext context,
    Color borderColor,
    bool isDark,
  ) {
    return _buildPlaceholder(
      title: 'Processing',
      subtitle: 'On-device engine ready.',
      icon: Icons.hourglass_empty_outlined,
      borderColor: borderColor,
      isDark: isDark,
    );
  }

  Widget _buildResultStep(
    BuildContext context,
    Color borderColor,
    bool isDark,
  ) {
    return _buildPlaceholder(
      title: 'Result',
      subtitle: 'Processing complete.',
      icon: Icons.check_circle_outline,
      borderColor: borderColor,
      isDark: isDark,
    );
  }

  // --- Compress PDF Specific Steps ---

  String _getQualityDescriptor(int q) {
    if (q <= 40) return '(Smallest Size)';
    if (q <= 70) return '(Balanced)';
    return '(High Quality)';
  }

  Widget _buildPresetChip({
    required String label,
    required String sublabel,
    required bool isSelected,
    required VoidCallback onTap,
    required Color borderColor,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5)),
          border: Border.all(
            color: isSelected ? Colors.transparent : borderColor,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? Colors.white : Colors.black),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? (isDark ? Colors.black87 : Colors.white70)
                    : (isDark ? Colors.white54 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompressPdfOptionsStep(
    BuildContext context,
    Color borderColor,
    bool isDark,
  ) {
    if (_selectedFiles.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 36,
            color: Colors.orange,
          ),
          const SizedBox(height: 12),
          const Text(
            'No PDF file selected.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => setState(() => _currentStepIndex = 0),
            child: const Text('Back to file selection'),
          ),
        ],
      );
    }

    final file = _selectedFiles.first;
    final fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'document.pdf';
    final fileSizeBytes = file.existsSync() ? file.lengthSync() : 0;
    final formattedSize = fileSizeBytes < 1024 * 1024
        ? '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB'
        : '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // File summary card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141414) : const Color(0xFFF9F9F9),
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: Color(0xFFFF9500),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Input PDF Ready • $formattedSize',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        const Text(
          'Compression Preset',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose an optimization level for size vs. clarity:',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 12),

        // Preset Chips
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildPresetChip(
              label: 'Recommended',
              sublabel: 'Balanced (65%)',
              isSelected:
                  _compressionPreset == PdfCompressionPreset.recommended,
              onTap: () {
                setState(() {
                  _compressionPreset = PdfCompressionPreset.recommended;
                  _compressQuality = 65;
                });
              },
              borderColor: borderColor,
              isDark: isDark,
            ),
            _buildPresetChip(
              label: 'Extreme',
              sublabel: 'Smallest size (40%)',
              isSelected: _compressionPreset == PdfCompressionPreset.extreme,
              onTap: () {
                setState(() {
                  _compressionPreset = PdfCompressionPreset.extreme;
                  _compressQuality = 40;
                });
              },
              borderColor: borderColor,
              isDark: isDark,
            ),
            _buildPresetChip(
              label: 'Basic',
              sublabel: 'High quality (80%)',
              isSelected: _compressionPreset == PdfCompressionPreset.basic,
              onTap: () {
                setState(() {
                  _compressionPreset = PdfCompressionPreset.basic;
                  _compressQuality = 80;
                });
              },
              borderColor: borderColor,
              isDark: isDark,
            ),
          ],
        ),

        const SizedBox(height: 22),

        // Quality Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Compression Quality',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            Text(
              '$_compressQuality% ${_getQualityDescriptor(_compressQuality)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
        Slider(
          value: _compressQuality.toDouble(),
          min: 20,
          max: 95,
          divisions: 15,
          label: '$_compressQuality%',
          onChanged: (val) {
            final q = val.round();
            setState(() {
              _compressQuality = q;
              if (q == 65) {
                _compressionPreset = PdfCompressionPreset.recommended;
              } else if (q == 40) {
                _compressionPreset = PdfCompressionPreset.extreme;
              } else if (q == 80) {
                _compressionPreset = PdfCompressionPreset.basic;
              } else {
                _compressionPreset = PdfCompressionPreset.custom;
              }
            });
          },
        ),

        const SizedBox(height: 12),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161616) : const Color(0xFFF4F4F4),
            border: Border.all(color: borderColor, width: 0.8),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Compresses images and optimizes PDF streams entirely on-device (100% confidential). Never sends documents to the cloud.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompressPdfProgressStep(
    BuildContext context,
    Color borderColor,
    bool isDark,
  ) {
    if (_compressError != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 44, color: Colors.redAccent),
          const SizedBox(height: 14),
          const Text(
            'Compression Failed',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _compressError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _currentStepIndex = 1),
                child: const Text('Back to options'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _startCompression,
                child: const Text('Retry'),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(
          color: isDark ? Colors.white : Colors.black,
          strokeWidth: 2.5,
        ),
        const SizedBox(height: 22),
        Text(
          _compressStage.isNotEmpty ? _compressStage : 'Optimizing PDF...',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        if (_compressProgress != null) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _compressProgress,
                minHeight: 4,
                color: isDark ? Colors.white : Colors.black,
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Processing document locally on your device.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildCompressPdfResultStep(
    BuildContext context,
    Color borderColor,
    bool isDark,
  ) {
    final res = _compressResult;
    if (res == null) {
      return const Center(child: Text('No result available.'));
    }

    final isOptimal = res.isAlreadyOptimal;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: isOptimal
                ? Colors.blue.withValues(alpha: 0.15)
                : Colors.green.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isOptimal ? Icons.thumb_up_alt_outlined : Icons.check,
            size: 30,
            color: isOptimal ? Colors.blueAccent : Colors.green,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          isOptimal ? 'Document Already Optimal!' : 'Compression Completed!',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          isOptimal
              ? 'This PDF is already at optimal size. Original quality preserved.'
              : 'Successfully reduced file size by ${res.reductionPercentage.toStringAsFixed(1)}%',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141414) : const Color(0xFFFAFAFA),
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: Color(0xFFFF9500),
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                res.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Original: ${res.formattedOriginalSize}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Compressed: ${res.formattedSize}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (!isOptimal) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '-${res.reductionPercentage.toStringAsFixed(1)}% space saved',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: _isCompressedSavedToFiles
                  ? null
                  : _handleDownloadCompressedPdf,
              icon: Icon(
                _isCompressedSavedToFiles
                    ? Icons.check
                    : Icons.download_outlined,
                size: 18,
              ),
              label: Text(
                _isCompressedSavedToFiles ? 'Saved to Files' : 'Save to Files',
              ),
            ),
            ElevatedButton.icon(
              onPressed: _handleShareCompressedPdf,
              icon: const Icon(Icons.share_outlined, size: 18),
              label: const Text('Share PDF'),
            ),
            OutlinedButton.icon(
              onPressed: _resetFlow,
              icon: const Icon(Icons.refresh_outlined, size: 18),
              label: const Text('Compress Another'),
            ),
          ],
        ),
      ],
    );
  }

  // --- Merge PDF Specific Steps ---

  Widget _buildMergePdfOptionsStep(
    BuildContext context,
    Color borderColor,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Merge Order',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Pages from PDF 1 will be followed by pages from PDF 2. If either PDF is password-protected, you will be prompted to unlock it.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 16),
        for (int i = 0; i < _selectedFiles.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414) : const Color(0xFFFAFAFA),
              border: Border.all(color: borderColor, width: 0.8),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: isDark ? Colors.white12 : Colors.black12,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 18,
                  color: Color(0xFFFF9500),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedFiles[i].uri.pathSegments.last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (_selectedFiles.length == 2) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  final first = _selectedFiles[0];
                  _selectedFiles[0] = _selectedFiles[1];
                  _selectedFiles[1] = first;
                });
              },
              icon: const Icon(Icons.swap_vert, size: 16),
              label: const Text('Swap Order'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        const Text(
          'Output File Name',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _mergeOutputNameController,
          decoration: const InputDecoration(
            hintText: 'merged_document',
            suffixText: '.pdf',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildMergePdfProgressStep(
    BuildContext context,
    Color borderColor,
    bool isDark,
  ) {
    if (_mergeError != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 14),
          const Text(
            'Merge Failed',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _mergeError!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _mergeError = null;
                _currentStepIndex = 1;
              });
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Back to Options'),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          _mergeStage.isNotEmpty ? _mergeStage : 'Merging PDFs...',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        if (_mergeProgress != null) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _mergeProgress,
                minHeight: 4,
                color: isDark ? Colors.white : Colors.black,
                backgroundColor: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Merging documents locally on your device.',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildMergePdfResultStep(
    BuildContext context,
    Color borderColor,
    bool isDark,
  ) {
    final res = _mergeResult;
    if (res == null) {
      return const Center(child: Text('No result available.'));
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 30, color: Colors.green),
        ),
        const SizedBox(height: 14),
        const Text(
          'PDFs Merged!',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          '${res.totalPageCount} ${res.totalPageCount == 1 ? 'page' : 'pages'} • ${res.formattedSize}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141414) : const Color(0xFFFAFAFA),
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: Color(0xFFFF9500),
                  size: 30,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                res.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _handleShareMergedPdf,
              icon: const Icon(Icons.share_outlined, size: 16),
              label: const Text('Share'),
            ),
            ElevatedButton.icon(
              onPressed: _isMergedSavedToFiles
                  ? null
                  : _handleDownloadMergedPdf,
              icon: Icon(
                _isMergedSavedToFiles ? Icons.check : Icons.save_alt_outlined,
                size: 16,
              ),
              label: Text(
                _isMergedSavedToFiles ? 'Saved to Files' : 'Save to Files',
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                final encodedPath = Uri.encodeComponent(res.outputPath);
                final encodedTitle = Uri.encodeComponent(res.fileName);
                context.push(
                  '/pdf-viewer?path=$encodedPath&title=$encodedTitle',
                );
              },
              icon: const Icon(Icons.visibility_outlined, size: 16),
              label: const Text('View PDF'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSplitPdfOptionsStep(
    BuildContext context,
    Color borderColor,
    bool isDark,
  ) {
    if (_selectedFiles.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 36,
            color: Colors.orange,
          ),
          const SizedBox(height: 12),
          const Text(
            'No PDF file selected.',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => setState(() => _currentStepIndex = 0),
            child: const Text('Back to file selection'),
          ),
        ],
      );
    }

    final file = _selectedFiles.first;
    final fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'document.pdf';
    final fileSizeBytes = file.existsSync() ? file.lengthSync() : 0;
    final formattedSize = fileSizeBytes < 1024 * 1024
        ? '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB'
        : '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File summary card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414) : const Color(0xFFF9F9F9),
              border: Border.all(color: borderColor, width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.call_split_outlined,
                    color: Color(0xFF007AFF),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$formattedSize • $_splitTotalPages ${_splitTotalPages == 1 ? 'page' : 'pages'}'
                        '${_splitIsEncrypted ? ' • Password-protected' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Splitting mode selection
          Text(
            'Splitting Mode',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Custom Ranges'),
                selected: _splitMode == SplitMode.customRanges,
                onSelected: (val) {
                  if (val) {
                    setState(() => _splitMode = SplitMode.customRanges);
                    _updateSplitValidation();
                  }
                },
              ),
              ChoiceChip(
                label: const Text('Every N Pages'),
                selected: _splitMode == SplitMode.everyNPages,
                onSelected: (val) {
                  if (val) {
                    setState(() => _splitMode = SplitMode.everyNPages);
                    _updateSplitValidation();
                  }
                },
              ),
              ChoiceChip(
                label: const Text('Extract All Pages'),
                selected: _splitMode == SplitMode.extractAllPages,
                onSelected: (val) {
                  if (val) {
                    setState(() => _splitMode = SplitMode.extractAllPages);
                    _updateSplitValidation();
                  }
                },
              ),
              ChoiceChip(
                label: const Text('Split into N Parts'),
                selected: _splitMode == SplitMode.splitIntoNParts,
                onSelected: (val) {
                  if (val) {
                    setState(() => _splitMode = SplitMode.splitIntoNParts);
                    _updateSplitValidation();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Mode-specific configuration
          if (_splitMode == SplitMode.customRanges) ...[
            Text(
              'Page Ranges',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _splitRangesController,
              decoration: InputDecoration(
                hintText: 'e.g. 1-3, 5, 8-10',
                helperText:
                    'Comma-separated groups (1-$_splitTotalPages). Each group becomes its own file.',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) => _updateSplitValidation(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: Text('All (1-$_splitTotalPages)'),
                  onPressed: () {
                    _splitRangesController.text = '1-$_splitTotalPages';
                    _updateSplitValidation();
                  },
                ),
                if (_splitTotalPages >= 2) ...[
                  ActionChip(
                    label: Text('First half (1-${_splitTotalPages ~/ 2})'),
                    onPressed: () {
                      _splitRangesController.text =
                          '1-${_splitTotalPages ~/ 2}';
                      _updateSplitValidation();
                    },
                  ),
                  ActionChip(
                    label: Text(
                      'Second half (${(_splitTotalPages ~/ 2) + 1}-$_splitTotalPages)',
                    ),
                    onPressed: () {
                      _splitRangesController.text =
                          '${(_splitTotalPages ~/ 2) + 1}-$_splitTotalPages';
                      _updateSplitValidation();
                    },
                  ),
                ],
              ],
            ),
          ] else if (_splitMode == SplitMode.everyNPages) ...[
            Text(
              'Pages per file (N)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton.outlined(
                  onPressed: () {
                    final curr =
                        int.tryParse(_splitEveryNController.text.trim()) ?? 1;
                    if (curr > 1) {
                      _splitEveryNController.text = '${curr - 1}';
                      _updateSplitValidation();
                    }
                  },
                  icon: const Icon(Icons.remove, size: 18),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _splitEveryNController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => _updateSplitValidation(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: () {
                    final curr =
                        int.tryParse(_splitEveryNController.text.trim()) ?? 1;
                    if (curr < _splitTotalPages) {
                      _splitEveryNController.text = '${curr + 1}';
                      _updateSplitValidation();
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Splits document into sequential chunks of N pages.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ] else if (_splitMode == SplitMode.extractAllPages) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F1F1F) : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 20,
                    color: Color(0xFF007AFF),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Every page will be saved as its own individual 1-page PDF file ($_splitTotalPages files total).',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_splitMode == SplitMode.splitIntoNParts) ...[
            Text(
              'Number of equal parts (N)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                IconButton.outlined(
                  onPressed: () {
                    final curr =
                        int.tryParse(_splitPartsController.text.trim()) ?? 2;
                    if (curr > 2) {
                      _splitPartsController.text = '${curr - 1}';
                      _updateSplitValidation();
                    }
                  },
                  icon: const Icon(Icons.remove, size: 18),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _splitPartsController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => _updateSplitValidation(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: () {
                    final curr =
                        int.tryParse(_splitPartsController.text.trim()) ?? 2;
                    if (curr < _splitTotalPages) {
                      _splitPartsController.text = '${curr + 1}';
                      _updateSplitValidation();
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Evenly distributes the $_splitTotalPages pages into N separate PDF files.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],

          const SizedBox(height: 18),

          // Output Filename Prefix
          Text(
            'Output Filename Prefix',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _splitPrefixController,
            decoration: const InputDecoration(
              hintText: 'e.g. document',
              helperText:
                  'Output files: [prefix]_pages_1-3.pdf (or _part1_pages_...)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 20),

          // Live Preview Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141414) : const Color(0xFFF9F9F9),
              border: Border.all(
                color: !_splitValidation.isValid
                    ? Colors.red.shade400
                    : (_splitValidation.hasSignificantGap
                        ? Colors.amber.shade600
                        : borderColor),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      !_splitValidation.isValid
                          ? Icons.error_outline
                          : (_splitValidation.hasSignificantGap
                              ? Icons.warning_amber_rounded
                              : Icons.preview_outlined),
                      size: 20,
                      color: !_splitValidation.isValid
                          ? Colors.red
                          : (_splitValidation.hasSignificantGap
                              ? Colors.amber.shade700
                              : const Color(0xFF007AFF)),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Split Output Preview',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (_splitValidation.isValid)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_splitValidation.fileCount} ${_splitValidation.fileCount == 1 ? 'file' : 'files'}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF007AFF),
                          ),
                        ),
                      ),
                  ],
                ),
                if (!_splitValidation.isValid) ...[
                  const SizedBox(height: 10),
                  Text(
                    _splitValidation.errorMessage ??
                        'Invalid split configuration.',
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else ...[
                  if (_splitValidation.hasSignificantGap &&
                      _splitValidation.omittedRangesSummary != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.amber.shade800,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pages ${_splitValidation.omittedRangesSummary} will be omitted from all output files. You\'ll confirm before splitting.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_splitValidation.fileCount >= 15) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Color(0xFF007AFF),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Generating ${_splitValidation.fileCount} files requires confirmation before proceeding.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF007AFF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  ..._splitValidation.groups.take(8).map((grp) {
                    final prefix = _splitPrefixController.text.trim().isNotEmpty
                        ? _splitPrefixController.text.trim()
                        : 'document';
                    final cleanRange = grp.rangeString.replaceAll(' ', '');
                    final sampleName = '${prefix}_pages_$cleanRange.pdf';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF222222)
                                  : const Color(0xFFEEEEEE),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${grp.index}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sampleName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Pages ${grp.rangeString} (${grp.pageCount} ${grp.pageCount == 1 ? 'page' : 'pages'})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (_splitValidation.groups.length > 8)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '+ ${_splitValidation.groups.length - 8} more files...',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSplitPdfProgressStep(
    BuildContext context,
    Color borderColor,
    bool isDark,
  ) {
    if (_splitError != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 40, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Split Failed',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _splitError!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _splitError = null;
                _currentStepIndex = 1;
              });
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try Again'),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        const SizedBox(height: 24),
        Text(
          _splitStage.isNotEmpty ? _splitStage : 'Splitting PDF...',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        if (_splitProgress != null) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: 240,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _splitProgress,
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${((_splitProgress ?? 0.0) * 100).toInt()}%',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Processing entirely on-device • 100% private',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      ],
    );
  }

  Widget _buildSplitPdfResultStep(
    BuildContext context,
    Color borderColor,
    bool isDark,
  ) {
    final res = _splitResult;
    if (res == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No split result available.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => setState(() => _currentStepIndex = 0),
              child: const Text('Back to file selection'),
            ),
          ],
        ),
      );
    }

    final fileCount = res.outputFiles.length;
    final fileCountText =
        fileCount == 1 ? '1 PDF file' : '$fileCount PDF files';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Success Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141414) : const Color(0xFFF9F9F9),
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Successfully split into $fileCountText',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Source: ${res.inputFileName} (${res.totalSourcePages} pages)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. Scrollable List of Generated Files
        Expanded(
          child: ListView.separated(
            itemCount: res.outputFiles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, idx) {
              final out = res.outputFiles[idx];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF141414)
                      : const Color(0xFFFBFBFB),
                  border: Border.all(color: borderColor, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${out.partIndex}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF007AFF),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            out.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              // Page count badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF222222)
                                      : const Color(0xFFEEEEEE),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${out.pageCount} ${out.pageCount == 1 ? 'page' : 'pages'} (pages ${out.sourceRange})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                              // File size badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF222222)
                                      : const Color(0xFFEEEEEE),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  out.formattedSize,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'View PDF',
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      onPressed: () {
                        final encodedPath = Uri.encodeComponent(out.outputPath);
                        final encodedTitle = Uri.encodeComponent(out.fileName);
                        context.push(
                          '/pdf-viewer?path=$encodedPath&title=$encodedTitle',
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Share',
                      icon: const Icon(Icons.share_outlined, size: 18),
                      onPressed: () {
                        // ignore: deprecated_member_use
                        Share.shareXFiles([XFile(out.outputPath)]);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),

        // 3. Bottom Sticky Bar: Save All to Files, Share All, and Done
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: borderColor, width: 1)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: ElevatedButton.icon(
                  onPressed: _isSplitSavedToFiles || _isSavingSplitPdf
                      ? null
                      : _handleSaveAllSplitPdfs,
                  icon: Icon(
                    _isSplitSavedToFiles ? Icons.check : Icons.save_alt_outlined,
                    size: 16,
                  ),
                  label: Text(
                    _isSavingSplitPdf
                        ? 'Saving...'
                        : (_isSplitSavedToFiles
                            ? 'Saved All'
                            : 'Save All to Files'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: OutlinedButton.icon(
                  onPressed: _handleShareAllSplitPdfs,
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: const Text('Share All'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _resetFlow,
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color borderColor,
    required bool isDark,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 26),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }
}
