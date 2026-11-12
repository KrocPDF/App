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

  // Multi-tool files state
  final List<File> _selectedFiles = [];

  @override
  void dispose() {
    _mergeOutputNameController.dispose();
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
                          if (_isConverting || _isCompressing) return;
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
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: SingleChildScrollView(
                      child: _buildStepContent(context, borderColor, isDark),
                    ),
                  ),
                ),
              ),

              // Step Navigation Bar
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
                        !_isMerging)
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
                                } else {
                                  setState(() => _currentStepIndex++);
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
