import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../core/constants/app_limits.dart';

class MergedPdfResult {
  final String outputPath;
  final String fileName;
  final int fileSizeBytes;
  final int totalPageCount;
  final List<int> sourcePageCounts;

  const MergedPdfResult({
    required this.outputPath,
    required this.fileName,
    required this.fileSizeBytes,
    required this.totalPageCount,
    required this.sourcePageCounts,
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    }
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class PdfEncryptionCheckResult {
  final List<String> encryptedFilePaths;
  final Map<String, String> invalidFiles;

  const PdfEncryptionCheckResult({
    this.encryptedFilePaths = const [],
    this.invalidFiles = const {},
  });

  bool get hasEncryptedFiles => encryptedFilePaths.isNotEmpty;
  bool get hasInvalidFiles => invalidFiles.isNotEmpty;
}

class PdfPasswordRequiredException implements Exception {
  final List<String> encryptedFilePaths;
  final String message;

  const PdfPasswordRequiredException({
    required this.encryptedFilePaths,
    this.message = 'One or more PDFs require a password to unlock.',
  });

  @override
  String toString() => message;
}

class PdfInvalidPasswordException implements Exception {
  final List<String> failedFilePaths;
  final String message;

  const PdfInvalidPasswordException({
    required this.failedFilePaths,
    this.message = 'Incorrect password for one or more PDFs.',
  });

  @override
  String toString() => message;
}

class PdfMergeService {
  const PdfMergeService();

  /// Validates that each file exists, is a .pdf within size limits, and checks
  /// whether any of the files require a password to open.
  Future<PdfEncryptionCheckResult> inspectFiles(List<String> inputPaths) async {
    final validPaths = <String>[];
    final invalidFiles = <String, String>{};

    for (final path in inputPaths) {
      final validationError = await _validateInputPath(path);
      if (validationError != null) {
        invalidFiles[path] = validationError;
      } else {
        validPaths.add(path);
      }
    }

    if (validPaths.isEmpty) {
      return PdfEncryptionCheckResult(invalidFiles: invalidFiles);
    }

    final isolateResult = await Isolate.run(
      () => _isolateInspectPdfs(validPaths),
    );

    final encrypted = List<String>.from(
      isolateResult['encrypted'] as List<dynamic>,
    );
    final parseInvalid = Map<String, String>.from(
      isolateResult['invalid'] as Map<dynamic, dynamic>,
    );

    return PdfEncryptionCheckResult(
      encryptedFilePaths: encrypted,
      invalidFiles: {...invalidFiles, ...parseInvalid},
    );
  }

  /// Merges strictly two PDF files on-device inside a background Isolate.
  Future<MergedPdfResult> mergePdfs({
    required List<String> inputPaths,
    Map<String, String> passwords = const {},
    String? outputDirectory,
    String? outputFileName,
    void Function(String status, double? progress)? onProgress,
  }) async {
    if (inputPaths.length != 2) {
      throw ArgumentError.value(
        inputPaths.length,
        'inputPaths',
        'Merge PDF requires strictly 2 PDF files.',
      );
    }

    onProgress?.call('Validating PDF files...', 0.1);

    for (final path in inputPaths) {
      final err = await _validateInputPath(path);
      if (err != null) {
        throw FormatException(err, path);
      }
    }

    onProgress?.call('Merging PDF pages...', 0.35);

    final payload = await Isolate.run(
      () => _isolateMergePdfs(inputPaths, passwords),
    );

    if (payload.containsKey('missingPasswordPaths')) {
      final paths = List<String>.from(
        payload['missingPasswordPaths'] as List<dynamic>,
      );
      throw PdfPasswordRequiredException(encryptedFilePaths: paths);
    }

    if (payload.containsKey('invalidPasswordPaths')) {
      final paths = List<String>.from(
        payload['invalidPasswordPaths'] as List<dynamic>,
      );
      throw PdfInvalidPasswordException(failedFilePaths: paths);
    }

    if (payload.containsKey('error')) {
      throw FormatException(payload['error'] as String);
    }

    onProgress?.call('Saving merged PDF...', 0.85);

    final mergedBytes = payload['bytes'] as Uint8List;
    final pageCounts = List<int>.from(payload['pageCounts'] as List<dynamic>);
    final totalPageCount = pageCounts.fold<int>(0, (sum, c) => sum + c);

    final String dirPath;
    if (outputDirectory != null && outputDirectory.isNotEmpty) {
      dirPath = outputDirectory;
    } else {
      dirPath = (await getTemporaryDirectory()).path;
    }

    final targetDir = Directory(dirPath);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final rawCustomName = outputFileName?.trim();
    final String displayFileName;
    final String diskFileName;
    if (rawCustomName != null && rawCustomName.isNotEmpty) {
      final base = rawCustomName.toLowerCase().endsWith('.pdf')
          ? rawCustomName.substring(0, rawCustomName.length - 4)
          : rawCustomName;
      final sanitized = base.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      displayFileName = '$sanitized.pdf';
      diskFileName = '${sanitized}_$timestamp.pdf';
    } else {
      displayFileName = 'merged_document.pdf';
      diskFileName = 'merged_$timestamp.pdf';
    }

    final outputPath = '$dirPath/$diskFileName';
    await File(outputPath).writeAsBytes(mergedBytes);

    onProgress?.call('Completed', 1.0);

    return MergedPdfResult(
      outputPath: outputPath,
      fileName: displayFileName,
      fileSizeBytes: mergedBytes.length,
      totalPageCount: totalPageCount,
      sourcePageCounts: pageCounts,
    );
  }

  Future<String?> _validateInputPath(String path) async {
    if (!path.toLowerCase().endsWith('.pdf')) {
      return 'Only .pdf files are supported for Merge PDF.';
    }
    final file = File(path);
    if (!await file.exists()) {
      return 'Selected PDF file does not exist on disk.';
    }
    final length = await file.length();
    if (length == 0) {
      return 'Selected PDF file is empty.';
    }
    if (length > AppLimits.maxLocalFileBytes) {
      return 'File exceeds the ${AppLimits.formattedLimitMb} local limit.';
    }
    return null;
  }
}

bool _isPasswordError(Object error) {
  final msg = error.toString().toLowerCase();
  return msg.contains('password') ||
      msg.contains('encrypt') ||
      msg.contains('security');
}

Future<Map<String, dynamic>> _isolateInspectPdfs(List<String> paths) async {
  final encrypted = <String>[];
  final invalid = <String, String>{};

  for (final path in paths) {
    sf.PdfDocument? doc;
    try {
      final bytes = File(path).readAsBytesSync();
      doc = sf.PdfDocument(inputBytes: bytes);
    } catch (e) {
      if (_isPasswordError(e)) {
        encrypted.add(path);
      } else {
        invalid[path] = 'Unable to read PDF: $e';
      }
    } finally {
      doc?.dispose();
    }
  }

  return {'encrypted': encrypted, 'invalid': invalid};
}

Future<Map<String, dynamic>> _isolateMergePdfs(
  List<String> paths,
  Map<String, String> passwords,
) async {
  final openedDocs = <sf.PdfDocument>[];
  final missingPasswordPaths = <String>[];
  final invalidPasswordPaths = <String>[];
  sf.PdfDocument? mergedDoc;

  try {
    for (final path in paths) {
      final bytes = File(path).readAsBytesSync();
      final suppliedPassword = passwords[path];
      try {
        final doc = sf.PdfDocument(
          inputBytes: bytes,
          password: suppliedPassword,
        );
        openedDocs.add(doc);
      } catch (e) {
        if (_isPasswordError(e)) {
          if (suppliedPassword == null || suppliedPassword.isEmpty) {
            missingPasswordPaths.add(path);
          } else {
            invalidPasswordPaths.add(path);
          }
        } else {
          return {'error': 'Invalid PDF file ($path): $e'};
        }
      }
    }

    if (missingPasswordPaths.isNotEmpty) {
      return {'missingPasswordPaths': missingPasswordPaths};
    }
    if (invalidPasswordPaths.isNotEmpty) {
      return {'invalidPasswordPaths': invalidPasswordPaths};
    }

    mergedDoc = sf.PdfDocument();
    mergedDoc.pageSettings.margins.all = 0;
    final pageCounts = <int>[];

    for (final sourceDoc in openedDocs) {
      pageCounts.add(sourceDoc.pages.count);
      for (int i = 0; i < sourceDoc.pages.count; i++) {
        final sourcePage = sourceDoc.pages[i];
        final template = sourcePage.createTemplate();
        mergedDoc.pageSettings.size = sourcePage.size;
        mergedDoc.pageSettings.orientation =
            sourcePage.size.width > sourcePage.size.height
            ? sf.PdfPageOrientation.landscape
            : sf.PdfPageOrientation.portrait;
        final targetPage = mergedDoc.pages.add();
        targetPage.graphics.drawPdfTemplate(template, Offset.zero);
      }
    }

    final outBytes = Uint8List.fromList(mergedDoc.saveSync());
    return {'bytes': outBytes, 'pageCounts': pageCounts};
  } catch (e) {
    return {'error': 'Failed to merge PDFs: $e'};
  } finally {
    mergedDoc?.dispose();
    for (final doc in openedDocs) {
      doc.dispose();
    }
  }
}
