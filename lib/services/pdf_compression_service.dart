import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as p;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart' as rx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

enum PdfCompressionPreset { extreme, recommended, basic, custom }

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
  const PdfCompressionService();

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
    try {
      final sfDoc = sf.PdfDocument(inputBytes: originalBytes);
      pageCount = sfDoc.pages.count;
      sfDoc.dispose();
    } catch (_) {}

    // 1. Lossless stream compression with Syncfusion
    onProgress?.call('Optimizing PDF streams...', 0.25);
    Uint8List? sfOnlyBytes;
    try {
      final sfDoc = sf.PdfDocument(inputBytes: originalBytes);
      sfDoc.compressionLevel = sf.PdfCompressionLevel.best;
      sfOnlyBytes = Uint8List.fromList(sfDoc.saveSync());
      sfDoc.dispose();
    } catch (_) {}

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
    final double scale = targetDpi / 72.0;

    Uint8List? rasterCompressedBytes;
    try {
      final doc = await rx.PdfDocument.openFile(inputPath);
      final totalPages = doc.pages.length;
      pageCount = totalPages;

      final outputPdf = pw.Document();
      for (int i = 0; i < totalPages; i++) {
        final pageNum = i + 1;
        final stepProgress = 0.3 + (0.55 * (i / totalPages));
        onProgress?.call(
          'Optimizing page $pageNum of $totalPages...',
          stepProgress,
        );

        final page = doc.pages[i];
        final rendered = await page.render(
          fullWidth: page.width * scale,
          fullHeight: page.height * scale,
        );

        if (rendered != null) {
          final decoded = img.Image.fromBytes(
            width: rendered.width,
            height: rendered.height,
            bytes: rendered.pixels.buffer,
            order: img.ChannelOrder.bgra,
          );
          rendered.dispose();

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
        }
      }
      await doc.dispose();

      onProgress?.call('Rebuilding optimized PDF...', 0.88);
      final rawRasterBytes = await outputPdf.save();

      // Run stream compression on the raster-rebuilt PDF
      final sfRasterDoc = sf.PdfDocument(inputBytes: rawRasterBytes);
      sfRasterDoc.compressionLevel = sf.PdfCompressionLevel.best;
      rasterCompressedBytes = Uint8List.fromList(sfRasterDoc.saveSync());
      sfRasterDoc.dispose();
    } catch (_) {}

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
}
