import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

import '../core/constants/app_limits.dart';

/// Available splitting modes supported by KrocPDF.
enum SplitMode {
  customRanges,
  everyNPages,
  extractAll,
  equalParts;

  static const SplitMode extractAllPages = SplitMode.extractAll;
  static const SplitMode splitIntoNParts = SplitMode.equalParts;
}

/// Inspection result of a PDF document.
class PdfInspectionResult {
  final int pageCount;
  final bool isEncrypted;

  const PdfInspectionResult({
    required this.pageCount,
    required this.isEncrypted,
  });
}

/// Represents a single output group produced by splitting.
class SplitGroup {
  final int partIndex; // 1-based index (e.g. 1 for Part 1)
  final List<int> pageNumbers; // 1-based page numbers in source document
  final String label; // Human-friendly label, e.g. "Part 1: pages 1–3"
  final String suggestedFileName; // e.g. "Document_pages_1-3.pdf"

  const SplitGroup({
    required this.partIndex,
    required this.pageNumbers,
    required this.label,
    required this.suggestedFileName,
  });

  int get index => partIndex;
  int get pageCount => pageNumbers.length;

  String get rangeString => pageNumbers.isEmpty
      ? ''
      : (pageNumbers.length == 1
            ? '${pageNumbers.first}'
            : '${pageNumbers.first}–${pageNumbers.last}');

  /// Returns 0-based page indices for internal PDF page operations.
  List<int> get pageIndices => pageNumbers.map((p) => p - 1).toList();
}

/// Validation result with live preview of parsed split groups.
class SplitValidationResult {
  final bool isValid;
  final String? errorMessage;
  final List<SplitGroup> groups;
  final List<int> missingPages; // 1-based page numbers not in any group
  final bool exceedsHardCap; // True if > 50 files
  final bool requiresCountConfirmation; // True if > 15 files

  const SplitValidationResult({
    required this.isValid,
    this.errorMessage,
    this.groups = const [],
    this.missingPages = const [],
    this.exceedsHardCap = false,
    this.requiresCountConfirmation = false,
  });

  bool get hasSignificantGap => missingPages.length > 2;
  int get totalOutputFiles => groups.length;
  int get fileCount => totalOutputFiles;

  String? get omittedRangesSummary =>
      missingPages.isEmpty ? null : formatMissingRanges();

  /// Formats missing pages into friendly range strings (e.g. "4-7, 10").
  String formatMissingRanges() {
    if (missingPages.isEmpty) {
      return '';
    }
    final ranges = <String>[];
    int? rangeStart;
    int? prev;

    for (final p in missingPages) {
      if (rangeStart == null) {
        rangeStart = p;
        prev = p;
      } else if (p == prev! + 1) {
        prev = p;
      } else {
        ranges.add(rangeStart == prev ? '$rangeStart' : '$rangeStart–$prev');
        rangeStart = p;
        prev = p;
      }
    }
    if (rangeStart != null) {
      ranges.add(rangeStart == prev ? '$rangeStart' : '$rangeStart–$prev');
    }
    return ranges.join(', ');
  }
}

/// Result metadata for an individual generated output PDF file.
class SplitOutputFile {
  final int partIndex;
  final String outputPath;
  final String fileName;
  final int fileSizeBytes;
  final int pageCount;
  final List<int> pageNumbers;

  const SplitOutputFile({
    this.partIndex = 1,
    required this.outputPath,
    required this.fileName,
    required this.fileSizeBytes,
    required this.pageCount,
    required this.pageNumbers,
  });

  String get sourceRange => pageNumbers.isEmpty
      ? ''
      : (pageNumbers.length == 1
            ? '${pageNumbers.first}'
            : '${pageNumbers.first}–${pageNumbers.last}');

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

/// Result of a completed Split PDF operation.
class SplitPdfResult {
  final List<SplitOutputFile> files;
  final int totalSourcePages;
  final String sourceFileName;

  const SplitPdfResult({
    required this.files,
    required this.totalSourcePages,
    required this.sourceFileName,
  });

  int get totalFiles => files.length;
  List<SplitOutputFile> get outputFiles => files;
  String get inputFileName => sourceFileName;
}

/// Range parsing and validation engine.
class SplitRangeValidator {
  static const int maxOutputFilesCap = 50;
  static const int confirmationThreshold = 15;

  static SplitValidationResult validateRanges(
    String input,
    int totalPages, {
    String prefix = 'document',
  }) => validate(
    mode: SplitMode.customRanges,
    totalPages: totalPages,
    customRangesInput: input,
    prefix: prefix,
  );

  static SplitValidationResult validateEveryNPages(
    int n,
    int totalPages, {
    String prefix = 'document',
  }) => validate(
    mode: SplitMode.everyNPages,
    totalPages: totalPages,
    everyN: n,
    prefix: prefix,
  );

  static SplitValidationResult validateExtractAllPages(
    int totalPages, {
    String prefix = 'document',
  }) => validate(
    mode: SplitMode.extractAll,
    totalPages: totalPages,
    prefix: prefix,
  );

  static SplitValidationResult validateSplitIntoNParts(
    int parts,
    int totalPages, {
    String prefix = 'document',
  }) => validate(
    mode: SplitMode.equalParts,
    totalPages: totalPages,
    equalParts: parts,
    prefix: prefix,
  );

  /// Parses and validates page ranges for any of the 4 Split modes.
  static SplitValidationResult validate({
    required SplitMode mode,
    required int totalPages,
    String? customRangesInput,
    int? everyN,
    int? equalParts,
    String prefix = 'document',
  }) {
    if (totalPages <= 0) {
      return const SplitValidationResult(
        isValid: false,
        errorMessage: 'Source document has no pages.',
      );
    }

    final sanitizedPrefix = _sanitizePrefix(prefix);

    switch (mode) {
      case SplitMode.extractAll:
        return _buildExtractAll(totalPages, sanitizedPrefix);
      case SplitMode.everyNPages:
        return _buildEveryN(totalPages, everyN ?? 2, sanitizedPrefix);
      case SplitMode.equalParts:
        return _buildEqualParts(totalPages, equalParts ?? 2, sanitizedPrefix);
      case SplitMode.customRanges:
        return _buildCustomRanges(
          totalPages,
          customRangesInput ?? '',
          sanitizedPrefix,
        );
    }
  }

  static String _sanitizePrefix(String raw) {
    var p = raw.trim();
    if (p.toLowerCase().endsWith('.pdf')) {
      p = p.substring(0, p.length - 4);
    }
    p = p.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return p.isEmpty ? 'document' : p;
  }

  static SplitValidationResult _buildExtractAll(int totalPages, String prefix) {
    if (totalPages > maxOutputFilesCap) {
      return SplitValidationResult(
        isValid: false,
        errorMessage:
            'Extract All would generate $totalPages files (maximum $maxOutputFilesCap allowed). Use Every N Pages or Page Ranges.',
        exceedsHardCap: true,
      );
    }

    final groups = <SplitGroup>[];
    for (int p = 1; p <= totalPages; p++) {
      groups.add(
        SplitGroup(
          partIndex: p,
          pageNumbers: [p],
          label: 'Page $p',
          suggestedFileName: '${prefix}_page_$p.pdf',
        ),
      );
    }

    return SplitValidationResult(
      isValid: true,
      groups: groups,
      missingPages: const [],
      requiresCountConfirmation: totalPages > confirmationThreshold,
    );
  }

  static SplitValidationResult _buildEveryN(
    int totalPages,
    int n,
    String prefix,
  ) {
    if (n < 1) {
      return const SplitValidationResult(
        isValid: false,
        errorMessage: 'Chunk size must be at least 1 page.',
      );
    }

    final totalFiles = (totalPages / n).ceil();
    if (totalFiles > maxOutputFilesCap) {
      return SplitValidationResult(
        isValid: false,
        errorMessage:
            'Splitting every $n pages would produce $totalFiles files (maximum $maxOutputFilesCap allowed). Increase chunk size.',
        exceedsHardCap: true,
      );
    }

    final groups = <SplitGroup>[];
    int partIdx = 1;
    for (int start = 1; start <= totalPages; start += n) {
      final end = (start + n - 1).clamp(1, totalPages);
      final pages = [for (int i = start; i <= end; i++) i];
      final rangeStr = start == end ? '$start' : '$start–$end';
      final fileRangeStr = start == end ? '$start' : '$start-$end';

      groups.add(
        SplitGroup(
          partIndex: partIdx,
          pageNumbers: pages,
          label: 'Part $partIdx: pages $rangeStr',
          suggestedFileName: '${prefix}_part${partIdx}_pages_$fileRangeStr.pdf',
        ),
      );
      partIdx++;
    }

    return SplitValidationResult(
      isValid: true,
      groups: groups,
      missingPages: const [],
      requiresCountConfirmation: groups.length > confirmationThreshold,
    );
  }

  static SplitValidationResult _buildEqualParts(
    int totalPages,
    int parts,
    String prefix,
  ) {
    if (parts < 2) {
      return const SplitValidationResult(
        isValid: false,
        errorMessage: 'Parts count must be at least 2.',
      );
    }
    if (parts > totalPages) {
      return SplitValidationResult(
        isValid: false,
        errorMessage:
            'Cannot split $totalPages pages into $parts parts (more parts than pages).',
      );
    }
    if (parts > maxOutputFilesCap) {
      return SplitValidationResult(
        isValid: false,
        errorMessage:
            'Cannot exceed $maxOutputFilesCap output files (requested $parts).',
        exceedsHardCap: true,
      );
    }

    final groups = <SplitGroup>[];
    final baseSize = totalPages ~/ parts;
    final remainder = totalPages % parts;

    int currentStart = 1;
    for (int i = 0; i < parts; i++) {
      final chunkSize = baseSize + (i < remainder ? 1 : 0);
      final currentEnd = currentStart + chunkSize - 1;
      final pages = [for (int p = currentStart; p <= currentEnd; p++) p];
      final rangeStr = currentStart == currentEnd
          ? '$currentStart'
          : '$currentStart–$currentEnd';
      final fileRangeStr = currentStart == currentEnd
          ? '$currentStart'
          : '$currentStart-$currentEnd';

      groups.add(
        SplitGroup(
          partIndex: i + 1,
          pageNumbers: pages,
          label: 'Part ${i + 1}: pages $rangeStr',
          suggestedFileName: '${prefix}_part${i + 1}_pages_$fileRangeStr.pdf',
        ),
      );
      currentStart = currentEnd + 1;
    }

    return SplitValidationResult(
      isValid: true,
      groups: groups,
      missingPages: const [],
      requiresCountConfirmation: parts > confirmationThreshold,
    );
  }

  static SplitValidationResult _buildCustomRanges(
    int totalPages,
    String input,
    String prefix,
  ) {
    final raw = input.trim();
    if (raw.isEmpty) {
      return const SplitValidationResult(
        isValid: false,
        errorMessage: 'Enter one or more page ranges (e.g. 1-3, 5, 8-12).',
      );
    }

    final segments = raw.split(',');
    final groups = <SplitGroup>[];
    final includedPages = <int>{};
    int partIdx = 1;

    for (final seg in segments) {
      final s = seg.trim();
      if (s.isEmpty) {
        continue;
      }

      if (s.contains('-')) {
        final parts = s.split('-');
        if (parts.length != 2) {
          return SplitValidationResult(
            isValid: false,
            errorMessage: 'Invalid range syntax "$s". Use format "start-end".',
          );
        }
        final start = int.tryParse(parts[0].trim());
        final end = int.tryParse(parts[1].trim());
        if (start == null || end == null) {
          return SplitValidationResult(
            isValid: false,
            errorMessage: 'Range "$s" must contain valid numbers.',
          );
        }
        if (start < 1) {
          return SplitValidationResult(
            isValid: false,
            errorMessage: 'Page numbers must be 1 or greater (got $start).',
          );
        }
        if (start > totalPages) {
          return SplitValidationResult(
            isValid: false,
            errorMessage:
                'Page $start exceeds document page count of $totalPages.',
          );
        }
        if (end > totalPages) {
          return SplitValidationResult(
            isValid: false,
            errorMessage:
                'Page $end exceeds document page count of $totalPages.',
          );
        }
        if (start > end) {
          return SplitValidationResult(
            isValid: false,
            errorMessage:
                'Start page $start cannot be greater than end page $end in "$s".',
          );
        }

        final pages = [for (int p = start; p <= end; p++) p];
        includedPages.addAll(pages);
        final fileRangeStr = '$start-$end';
        groups.add(
          SplitGroup(
            partIndex: partIdx,
            pageNumbers: pages,
            label: 'Part $partIdx: pages $start–$end',
            suggestedFileName: '${prefix}_pages_$fileRangeStr.pdf',
          ),
        );
      } else {
        final single = int.tryParse(s);
        if (single == null) {
          return SplitValidationResult(
            isValid: false,
            errorMessage: 'Invalid page number "$s".',
          );
        }
        if (single < 1) {
          return SplitValidationResult(
            isValid: false,
            errorMessage: 'Page number must be 1 or greater (got $single).',
          );
        }
        if (single > totalPages) {
          return SplitValidationResult(
            isValid: false,
            errorMessage:
                'Page $single exceeds document page count of $totalPages.',
          );
        }

        includedPages.add(single);
        groups.add(
          SplitGroup(
            partIndex: partIdx,
            pageNumbers: [single],
            label: 'Part $partIdx: page $single',
            suggestedFileName: '${prefix}_page_$single.pdf',
          ),
        );
      }
      partIdx++;
    }

    if (groups.isEmpty) {
      return const SplitValidationResult(
        isValid: false,
        errorMessage: 'Enter at least one valid page range.',
      );
    }

    if (groups.length > maxOutputFilesCap) {
      return SplitValidationResult(
        isValid: false,
        errorMessage:
            'Custom ranges produce ${groups.length} files (maximum $maxOutputFilesCap allowed).',
        exceedsHardCap: true,
      );
    }

    // Determine missing pages (pages in 1..totalPages not present in any group)
    final missing = <int>[];
    for (int p = 1; p <= totalPages; p++) {
      if (!includedPages.contains(p)) {
        missing.add(p);
      }
    }

    return SplitValidationResult(
      isValid: true,
      groups: groups,
      missingPages: missing,
      requiresCountConfirmation: groups.length > confirmationThreshold,
    );
  }
}

/// On-device Split PDF engine powered by syncfusion_flutter_pdf.
class PdfSplitService {
  const PdfSplitService();

  /// Inspects a PDF file and returns its total page count and whether it is password protected.
  Future<PdfInspectionResult> inspectPdf(
    String path, {
    String? password,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const FormatException('Selected PDF file does not exist on disk.');
    }
    final length = await file.length();
    if (length == 0) {
      throw const FormatException('Selected PDF file is empty.');
    }
    if (length > AppLimits.maxLocalFileBytes) {
      throw FormatException(
        'File exceeds the ${AppLimits.formattedLimitMb} local limit.',
      );
    }

    final bytes = await file.readAsBytes();
    return await Isolate.run(() {
      sf.PdfDocument? doc;
      try {
        doc = sf.PdfDocument(inputBytes: bytes, password: password);
        return PdfInspectionResult(
          pageCount: doc.pages.count,
          isEncrypted: false,
        );
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('password') ||
            msg.contains('encrypt') ||
            msg.contains('security')) {
          return const PdfInspectionResult(pageCount: 0, isEncrypted: true);
        }
        throw FormatException('Unable to read PDF file: $e');
      } finally {
        doc?.dispose();
      }
    });
  }

  /// Splits a PDF document on-device inside a background Isolate.
  ///
  /// CRITICAL MEMORY GUARANTEE:
  /// Processes one output group at a time, immediately saving and disposing
  /// each output `PdfDocument` before allocating the next one.
  /// Peak memory stays flat ($O(1)$ with respect to total pages/files).
  Future<SplitPdfResult> splitPdf({
    required String inputPath,
    required List<SplitGroup> groups,
    String? password,
    String? outputPrefix,
    String? outputDirectory,
    void Function(String stage, double? progress)? onProgress,
  }) async {
    if (groups.isEmpty) {
      throw ArgumentError('At least one SplitGroup is required.');
    }
    if (groups.length > SplitRangeValidator.maxOutputFilesCap) {
      throw ArgumentError(
        'Cannot split into more than ${SplitRangeValidator.maxOutputFilesCap} files.',
      );
    }

    final file = File(inputPath);
    if (!await file.exists()) {
      throw const FormatException('Source PDF file does not exist.');
    }

    onProgress?.call('Reading document structure...', 0.05);
    final sourceBytes = await file.readAsBytes();

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

    // Convert groups into serializable structure for the Isolate
    final serializableGroups = groups.map((g) {
      return {
        'partIndex': g.partIndex,
        'pageIndices': g.pageIndices,
        'suggestedFileName': g.suggestedFileName,
      };
    }).toList();

    onProgress?.call('Initializing split engine...', 0.15);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final payload = await Isolate.run(() {
      return _isolateExecuteSplit(
        sourceBytes: sourceBytes,
        password: password,
        dirPath: dirPath,
        timestamp: timestamp,
        groups: serializableGroups,
      );
    });

    if (payload.containsKey('error')) {
      throw FormatException(payload['error'] as String);
    }

    final rawOutputs = payload['files'] as List<dynamic>;
    final totalSourcePages = payload['totalSourcePages'] as int;

    final outputFiles = rawOutputs.asMap().entries.map((entry) {
      final idx = entry.key;
      final map = entry.value as Map<dynamic, dynamic>;
      return SplitOutputFile(
        partIndex: idx + 1,
        outputPath: map['path'] as String,
        fileName: map['fileName'] as String,
        fileSizeBytes: map['size'] as int,
        pageCount: map['pageCount'] as int,
        pageNumbers: List<int>.from(map['pageNumbers'] as List<dynamic>),
      );
    }).toList();

    onProgress?.call('Completed', 1.0);

    final sourceFileName = file.uri.pathSegments.last;
    return SplitPdfResult(
      files: outputFiles,
      totalSourcePages: totalSourcePages,
      sourceFileName: sourceFileName,
    );
  }
}

/// Standalone top-level Isolate execution function.
Map<String, dynamic> _isolateExecuteSplit({
  required Uint8List sourceBytes,
  required String? password,
  required String dirPath,
  required int timestamp,
  required List<Map<String, dynamic>> groups,
}) {
  sf.PdfDocument? sourceDoc;
  try {
    sourceDoc = sf.PdfDocument(inputBytes: sourceBytes, password: password);
    final totalSourcePages = sourceDoc.pages.count;
    final outputList = <Map<String, dynamic>>[];

    for (int gIdx = 0; gIdx < groups.length; gIdx++) {
      final group = groups[gIdx];
      final pageIndices = List<int>.from(group['pageIndices'] as List<dynamic>);
      final suggestedFileName = group['suggestedFileName'] as String;

      // Ensure fileName has .pdf extension
      final cleanName = suggestedFileName.toLowerCase().endsWith('.pdf')
          ? suggestedFileName
          : '$suggestedFileName.pdf';

      // Disambiguate on-disk filename with unique timestamp
      final diskName =
          '${cleanName.substring(0, cleanName.length - 4)}_${timestamp}_p${gIdx + 1}.pdf';
      final diskPath = '$dirPath/$diskName';

      // 1. Create target document for this group ONLY
      final outDoc = sf.PdfDocument();
      outDoc.pageSettings.margins.all = 0;

      for (final pIdx in pageIndices) {
        if (pIdx < 0 || pIdx >= totalSourcePages) {
          outDoc.dispose();
          return {
            'error':
                'Page index $pIdx is out of bounds (1..$totalSourcePages).',
          };
        }

        final sourcePage = sourceDoc.pages[pIdx];
        final template = sourcePage.createTemplate();
        outDoc.pageSettings.size = sourcePage.size;
        outDoc.pageSettings.orientation =
            sourcePage.size.width > sourcePage.size.height
            ? sf.PdfPageOrientation.landscape
            : sf.PdfPageOrientation.portrait;

        final targetPage = outDoc.pages.add();
        targetPage.graphics.drawPdfTemplate(template, Offset.zero);
      }

      // 2. Save to disk immediately
      final outBytes = Uint8List.fromList(outDoc.saveSync());
      File(diskPath).writeAsBytesSync(outBytes);

      // 3. DISPOSE IMMEDIATELY to reclaim all memory buffers
      outDoc.dispose();

      outputList.add({
        'path': diskPath,
        'fileName': cleanName,
        'size': outBytes.length,
        'pageCount': pageIndices.length,
        'pageNumbers': pageIndices.map((i) => i + 1).toList(),
      });
    }

    return {'files': outputList, 'totalSourcePages': totalSourcePages};
  } catch (e) {
    return {'error': 'Failed during PDF split execution: $e'};
  } finally {
    sourceDoc?.dispose();
  }
}
