import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart' as rx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

enum PdfCompressionPreset { extreme, recommended, basic, custom }

typedef PdfRasterCompressor =
    Future<Uint8List?> Function({
      required String inputPath,
      required int quality,
      required double targetDpi,
      required void Function(int pageCount) onPageCountDetected,
      void Function(String status, double? progress)? onProgress,
    });

class CompressedPdfResult {
  final String outputPath;
  final String fileName;
  final int fileSizeBytes;
  final int originalSizeBytes;
  final int pageCount;
  final bool isAlreadyOptimal;

  const CompressedPdfResult({
    required this.outputPath,
    required this.fileName,
    required this.fileSizeBytes,
    required this.originalSizeBytes,
    required this.pageCount,
    this.isAlreadyOptimal = false,
  });

  double get reductionPercentage {
    if (originalSizeBytes <= 0 || fileSizeBytes >= originalSizeBytes) {
      return 0.0;
    }
    return ((originalSizeBytes - fileSizeBytes) / originalSizeBytes) * 100;
  }

  String get formattedSize => _formatSize(fileSizeBytes);
  String get formattedOriginalSize => _formatSize(originalSizeBytes);

  static String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class PdfCompressionService {
  final PdfRasterCompressor? rasterCompressor;

  const PdfCompressionService({this.rasterCompressor});

  Future<CompressedPdfResult> compressPdf({
    required String inputPath,
    required int quality,
    String? outputDirectory,
    void Function(String status, double? progress)? onProgress,
  }) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw FileSystemException('Input PDF file does not exist', inputPath);
    }

    final originalSizeBytes = await inputFile.length();
    final originalBytes = await inputFile.readAsBytes();

    onProgress?.call('Analyzing PDF structure...', 0.1);

    int pageCount = 1;
    bool anyParserSucceeded = false;

    sf.PdfDocument? inspectDoc;
    try {
      inspectDoc = sf.PdfDocument(inputBytes: originalBytes);
      pageCount = inspectDoc.pages.count;
      anyParserSucceeded = true;
    } catch (e) {
      debugPrint('PdfCompressionService: Syncfusion inspect failed: $e');
    } finally {
      inspectDoc?.dispose();
    }

    // 1. Lossless stream compression with Syncfusion
    onProgress?.call('Optimizing PDF streams...', 0.25);
    Uint8List? sfOnlyBytes;
    sf.PdfDocument? sfCompressDoc;
    try {
      sfCompressDoc = sf.PdfDocument(inputBytes: originalBytes);
      sfCompressDoc.compressionLevel = sf.PdfCompressionLevel.best;
      sfOnlyBytes = Uint8List.fromList(sfCompressDoc.saveSync());
      anyParserSucceeded = true;
    } catch (e) {
      debugPrint('PdfCompressionService: Syncfusion stream pass failed: $e');
    } finally {
      sfCompressDoc?.dispose();
    }

    // 2. Raster image recompression & downsampling
    // Effective DPI targets:
    // - Extreme (quality <= 45): ~80 DPI (draft / compact sharing)
    // - Recommended (quality <= 75): ~150 DPI (crisp mobile/tablet text reading)
    // - Basic (quality > 75): ~200 DPI (near-native archival clarity)
    final double targetDpi;
    if (quality <= 45) {
      targetDpi = 80.0;
    } else if (quality <= 75) {
      targetDpi = 150.0;
    } else {
      targetDpi = 200.0;
    }

    Uint8List? rasterCompressedBytes;
    if (rasterCompressor != null) {
      try {
        rasterCompressedBytes = await rasterCompressor!(
          inputPath: inputPath,
          quality: quality,
          targetDpi: targetDpi,
          onPageCountDetected: (count) => pageCount = count,
          onProgress: onProgress,
        );
        if (rasterCompressedBytes != null) {
          anyParserSucceeded = true;
        }
      } catch (e) {
        debugPrint('PdfCompressionService: Custom raster pass failed: $e');
      }
    } else {
      final rasterResult = await _compressWithPdfrx(
        inputPath: inputPath,
        quality: quality,
        targetDpi: targetDpi,
        onPageCountDetected: (count) => pageCount = count,
        onProgress: onProgress,
      );
      if (rasterResult.parserSucceeded) {
        anyParserSucceeded = true;
      }
      rasterCompressedBytes = rasterResult.bytes;
    }

    if (!anyParserSucceeded) {
      throw const FormatException(
        'Unable to parse or compress the selected PDF file.',
      );
    }

    onProgress?.call('Finalizing file...', 0.96);

    // Pick best candidate:
    Uint8List chosenBytes = originalBytes;
    bool isAlreadyOptimal = false;

    int bestSize = originalSizeBytes;
    if (sfOnlyBytes != null && sfOnlyBytes.length < bestSize) {
      bestSize = sfOnlyBytes.length;
      chosenBytes = sfOnlyBytes;
    }
    if (rasterCompressedBytes != null &&
        rasterCompressedBytes.length < bestSize) {
      bestSize = rasterCompressedBytes.length;
      chosenBytes = rasterCompressedBytes;
    }

    if (bestSize >= originalSizeBytes) {
      chosenBytes = originalBytes;
      isAlreadyOptimal = true;
    }

    final String dirPath;
    if (outputDirectory != null && outputDirectory.isNotEmpty) {
      dirPath = outputDirectory;
    } else {
      dirPath = (await getTemporaryDirectory()).path;
    }

    final rawName = inputFile.uri.pathSegments.isNotEmpty
        ? inputFile.uri.pathSegments.last
        : 'document.pdf';
    final dotIdx = rawName.lastIndexOf('.');
    final baseName = dotIdx > 0 ? rawName.substring(0, dotIdx) : rawName;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '$dirPath/${baseName}_compressed_$timestamp.pdf';
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(chosenBytes);

    return CompressedPdfResult(
      outputPath: outputPath,
      fileName: '${baseName}_compressed.pdf',
      fileSizeBytes: chosenBytes.length,
      originalSizeBytes: originalSizeBytes,
      pageCount: pageCount,
      isAlreadyOptimal: isAlreadyOptimal,
    );
  }

  Future<({Uint8List? bytes, bool parserSucceeded})> _compressWithPdfrx({
    required String inputPath,
    required int quality,
    required double targetDpi,
    required void Function(int pageCount) onPageCountDetected,
    void Function(String status, double? progress)? onProgress,
  }) async {
    final double scale = targetDpi / 72.0;
    rx.PdfDocument? doc;
    sf.PdfDocument? sfRasterDoc;
    bool parserSucceeded = false;

    try {
      doc = await rx.PdfDocument.openFile(inputPath);
      parserSucceeded = true;
      final totalPages = doc.pages.length;
      if (totalPages == 0) {
        return (bytes: null, parserSucceeded: true);
      }
      onPageCountDetected(totalPages);

      final outputPdf = pw.Document();
      bool allPagesRendered = true;

      for (int i = 0; i < totalPages; i++) {
        final pageNum = i + 1;
        final stepProgress = 0.3 + (0.55 * (i / totalPages));
        onProgress?.call(
          'Optimizing page $pageNum of $totalPages...',
          stepProgress,
        );

        final page = doc.pages[i];
        rx.PdfImage? rendered;
        try {
          rendered = await page.render(
            fullWidth: page.width * scale,
            fullHeight: page.height * scale,
          );
          if (rendered == null) {
            allPagesRendered = false;
            break;
          }

          final decoded = img.Image.fromBytes(
            width: rendered.width,
            height: rendered.height,
            bytes: rendered.pixels.buffer,
            order: img.ChannelOrder.bgra,
          );

          final compressedJpg = Uint8List.fromList(
            img.encodeJpg(decoded, quality: quality),
          );

          outputPdf.addPage(
            pw.Page(
              pageFormat: p.PdfPageFormat(page.width, page.height),
              margin: pw.EdgeInsets.zero,
              build: (context) => pw.FullPage(
                ignoreMargins: true,
                child: pw.Image(
                  pw.MemoryImage(compressedJpg),
                  fit: pw.BoxFit.fill,
                ),
              ),
            ),
          );
        } finally {
          rendered?.dispose();
        }
      }

      if (!allPagesRendered) {
        return (bytes: null, parserSucceeded: parserSucceeded);
      }

      onProgress?.call('Rebuilding optimized PDF...', 0.88);
      final rawRasterBytes = await outputPdf.save();

      // Run stream compression on the raster-rebuilt PDF
      sfRasterDoc = sf.PdfDocument(inputBytes: rawRasterBytes);
      sfRasterDoc.compressionLevel = sf.PdfCompressionLevel.best;
      final compressed = Uint8List.fromList(sfRasterDoc.saveSync());
      return (bytes: compressed, parserSucceeded: parserSucceeded);
    } catch (e) {
      debugPrint('PdfCompressionService: Raster pass failed: $e');
      return (bytes: null, parserSucceeded: parserSucceeded);
    } finally {
      sfRasterDoc?.dispose();
      await doc?.dispose();
    }
  }
}
