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
import '../../files/data/files_repository.dart';
import '../../files/domain/saved_document.dart';
import '../../home/domain/tool_item.dart';

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
  final ImageConversionService _conversionService = const ImageConversionService();

  String? _selectedImagePath;
  String _sourceFormat = '';
  int _sourceFileSizeBytes = 0;
  late String _targetFormat;
  int _quality = 92;
  bool _isConverting = false;
  String? _conversionError;
  ConvertedImageResult? _conversionResult;
  bool _isSavedToFiles = false;

  // Multi-tool files state
  final List<File> _selectedFiles = [];

  @override
  void initState() {
    super.initState();
    _currentStepIndex = widget.initialStepIndex;
    final requested = widget.format?.trim().toUpperCase();
    if (requested != null && ImageConversionService.supportedOutputFormats.contains(requested)) {
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
          final fileName = file.path.split(Platform.pathSeparator).last.split('/').last;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _pickImageFromStorage() async {
    final hasPermission = await StoragePermissionHelper.ensureStoragePermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission is required to browse images.')),
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
    final hasPermission = await StoragePermissionHelper.ensureStoragePermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission is required to browse files.')),
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
        final validation = validator.validateFile(file, allowedExtensions: allowedExtensions);

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
        setState(() {
          if (!allowMultiple) {
            _selectedFiles.clear();
          }
          _selectedFiles.addAll(validFiles);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick files: $e')),
        );
      }
    }
  }

  Future<void> _showSavedDocumentsPicker({required bool allowMultiple}) async {
    final savedDocs = ref.read(savedFilesProvider);
    if (!mounted) return;

    if (savedDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved documents in KrocPDF yet. Import or scan files first.'),
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
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: savedDocs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final doc = savedDocs[index];
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: theme.colorScheme.outline, width: 0.8),
                          ),
                          leading: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFFF9500)),
                          title: Text(
                            '${doc.title}.pdf',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
        final validation = validator.validateFile(file, allowedExtensions: ['pdf']);
        if (validation is Failure<bool, AppError>) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(validation.error.message)),
            );
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
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: savedDocs.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final doc = savedDocs[index];
                            final isChecked = selectedDocIds.contains(doc.id);
                            return CheckboxListTile(
                              value: isChecked,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: theme.colorScheme.outline, width: 0.8),
                              ),
                              secondary: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFFF9500)),
                              title: Text(
                                '${doc.title}.pdf',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                              subtitle: Text(
                                '${doc.formattedSize} • ${doc.pageCount} ${doc.pageCount == 1 ? 'page' : 'pages'}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                              onChanged: (val) {
                                setModalState(() {
                                  if (val == true) {
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
                            child: Text('Add Selected (${selectedDocIds.length})'),
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
          final valResult = validator.validateFile(file, allowedExtensions: ['pdf']);
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
    await Share.shareXFiles(
      [XFile(_conversionResult!.outputPath)],
    );
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
      await ref.read(savedFilesProvider.notifier).addExternalFile(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save file: $e')),
        );
      }
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
      _selectedFiles.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tool = ToolItem.findById(widget.toolId);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = theme.colorScheme.outline;

    final toolTitle = tool?.title ?? 'Tool Flow';
    final formatLabel = widget.format != null ? ' (${widget.format!.toUpperCase()})' : '';

    final bool canGoNext;
    if (_isImageConvert) {
      canGoNext = (_currentStepIndex == 0 && _selectedImagePath != null) ||
          (_currentStepIndex == 1);
    } else if (widget.toolId == 'office_to_pdf') {
      // Office to PDF is UI scaffolding only in this phase
      canGoNext = false;
    } else if (widget.toolId == 'merge_pdf') {
      canGoNext = (_currentStepIndex == 0 && _selectedFiles.length >= 2) ||
          (_currentStepIndex > 0);
    } else {
      canGoNext = (_currentStepIndex == 0 && _selectedFiles.isNotEmpty) ||
          (_currentStepIndex > 0);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('$toolTitle$formatLabel'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            children: [
              // Step Indicator Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: borderColor, width: 1)),
                ),
                child: Row(
                  children: List.generate(_steps.length, (index) {
                    final isCurrent = index == _currentStepIndex;
                    final isDone = index < _currentStepIndex;

                    return Expanded(
                      child: InkWell(
                        onTap: () {
                          if (_isConverting) return;
                          if (_isImageConvert) {
                            if (index == 0) {
                              setState(() => _currentStepIndex = index);
                            } else if (index == 1 && _selectedImagePath != null) {
                              setState(() => _currentStepIndex = index);
                            } else if (index == 2 && _selectedImagePath != null) {
                              _startConversion();
                            } else if (index == 3 && _conversionResult != null) {
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
                                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                color: isCurrent
                                    ? (isDark ? Colors.white : Colors.black)
                                    : (isDark ? Colors.white38 : Colors.black38),
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
                    if (_currentStepIndex > 0 && !_isConverting)
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
                                } else {
                                  setState(() => _currentStepIndex++);
                                }
                              }
                            : null,
                        child: Text(
                          _isImageConvert && _currentStepIndex == 1
                              ? 'Convert to $_targetFormat'
                              : 'Next step',
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: _resetFlow,
                        child: const Text('Convert another'),
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

  Widget _buildStepContent(BuildContext context, Color borderColor, bool isDark) {
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

  Widget _buildImageConvertSelectStep(BuildContext context, Color borderColor, bool isDark) {
    if (_selectedImagePath != null) {
      final fileName = _selectedImagePath!.split(Platform.pathSeparator).last.split('/').last;
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
                      constraints: const BoxConstraints(maxHeight: 180, maxWidth: 260),
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
                      color: isDark ? const Color(0xFF222222) : const Color(0xFFEEEEEE),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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

  Widget _buildImageConvertOptionsStep(BuildContext context, Color borderColor, bool isDark) {
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
              const Icon(Icons.check_circle_outline, size: 20, color: Colors.green),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Input Image Ready',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0),
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

  Widget _buildImageConvertProgressStep(BuildContext context, Color borderColor, bool isDark) {
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

  Widget _buildImageConvertResultStep(BuildContext context, Color borderColor, bool isDark) {
    final res = _conversionResult;
    if (res == null) {
      return const Center(child: Text('No result available.'));
    }

    final isPreviewable = res.format != 'HEIC' && File(res.outputPath).existsSync();

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
                    constraints: const BoxConstraints(maxHeight: 180, maxWidth: 260),
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
                    color: isDark ? const Color(0xFF222222) : const Color(0xFFECECEC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.insert_drive_file_outlined, size: 32),
                ),
              const SizedBox(height: 14),
              Text(
                res.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
              icon: Icon(_isSavedToFiles ? Icons.check : Icons.download_outlined, size: 18),
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

  Widget _buildSelectFilesStep(BuildContext context, Color borderColor, bool isDark) {
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

  Widget _buildOfficeSelectStep(BuildContext context, Color borderColor, bool isDark) {
    if (_selectedFiles.isNotEmpty) {
      final file = _selectedFiles.first;
      final fileName = file.uri.pathSegments.last;
      final size = file.existsSync() ? file.lengthSync() : 0;
      final ext = fileName.contains('.') ? fileName.split('.').last.toUpperCase() : 'DOC';

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
                  child: const Icon(Icons.description_outlined, color: Colors.blueAccent, size: 30),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
                const Icon(Icons.cloud_outlined, size: 20, color: Colors.blueAccent),
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
                  allowedExtensions: ['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'],
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

  Widget _buildMergePdfSelectStep(BuildContext context, Color borderColor, bool isDark) {
    if (_selectedFiles.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_selectedFiles.length} ${_selectedFiles.length == 1 ? 'file' : 'files'} selected',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              if (_selectedFiles.length < 2)
                const Text(
                  'Select at least 2 PDFs',
                  style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600),
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
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.picture_as_pdf_outlined, size: 20, color: Color(0xFFFF9500)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
                      onPressed: () => setState(() => _selectedFiles.removeAt(index)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
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
                onPressed: () => _showSavedDocumentsPicker(allowMultiple: true),
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
                  child: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFFFF9500), size: 24),
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
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
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
                onPressed: () => _showSavedDocumentsPicker(allowMultiple: false),
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

  Widget _buildImageToPdfSelectStep(BuildContext context, Color borderColor, bool isDark) {
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
                allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'],
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

  Widget _buildGenericSelectStep(BuildContext context, Color borderColor, bool isDark) {
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
          onPressed: () => _pickFilesFromDevice(allowedExtensions: ['pdf'], allowMultiple: false),
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('Browse Device Storage'),
        ),
      ],
    );
  }

  Widget _buildOptionsStep(BuildContext context, Color borderColor, bool isDark) {
    return _buildPlaceholder(
      title: 'Options',
      subtitle: 'Options configuration ready.',
      icon: Icons.tune_outlined,
      borderColor: borderColor,
      isDark: isDark,
    );
  }

  Widget _buildProgressStep(BuildContext context, Color borderColor, bool isDark) {
    return _buildPlaceholder(
      title: 'Processing',
      subtitle: 'On-device engine ready.',
      icon: Icons.hourglass_empty_outlined,
      borderColor: borderColor,
      isDark: isDark,
    );
  }

  Widget _buildResultStep(BuildContext context, Color borderColor, bool isDark) {
    return _buildPlaceholder(
      title: 'Result',
      subtitle: 'Processing complete.',
      icon: Icons.check_circle_outline,
      borderColor: borderColor,
      isDark: isDark,
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
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
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
