import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:krocpdf/services/pdf_compression_service.dart';
import 'package:pdf/pdf.dart' as p;
import 'package:pdf/widgets.dart' as pw;

void main() {
  group('CompressedPdfResult metrics', () {
    test('calculates reduction percentage correctly', () {
      const res = CompressedPdfResult(
        outputPath: '/path/out.pdf',
        fileName: 'out.pdf',
        fileSizeBytes: 500000,
        originalSizeBytes: 1000000,
        pageCount: 2,
      );

      expect(res.reductionPercentage, equals(50.0));
      expect(res.formattedSize, contains('488.3 KB'));
      expect(res.formattedOriginalSize, contains('976.6 KB'));
    });

    test('handles already optimal result with 0 reduction', () {
      const res = CompressedPdfResult(
        outputPath: '/path/out.pdf',
        fileName: 'out.pdf',
        fileSizeBytes: 1000000,
        originalSizeBytes: 1000000,
        pageCount: 1,
        isAlreadyOptimal: true,
      );

      expect(res.reductionPercentage, equals(0.0));
      expect(res.isAlreadyOptimal, isTrue);
    });
  });

  group('PdfCompressionService execution', () {
    test('compresses image-heavy PDF and reduces file size', () async {
      final tempDir = Directory.systemTemp.createTempSync('krocpdf_test_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final testImg = img.Image(width: 800, height: 1000);
      for (int y = 0; y < 1000; y++) {
        for (int x = 0; x < 800; x++) {
          testImg.setPixelRgb(
            x,
            y,
            (x * 4) % 255,
            (y * 2) % 255,
            (x + y) % 255,
          );
        }
      }
      final highQualityJpg = Uint8List.fromList(
        img.encodeJpg(testImg, quality: 95),
      );
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: p.PdfPageFormat.a4,
          build: (context) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Image(pw.MemoryImage(highQualityJpg)),
          ),
        ),
      );
      final originalBytes = await pdf.save();
      final tempInput = File('${tempDir.path}/input_image.pdf');
      await tempInput.writeAsBytes(originalBytes);

      // Inject a pure-Dart rasterizer for headless VM unit tests where native
      // pdfium binaries are unavailable.
      final service = PdfCompressionService(
        rasterCompressor:
            ({
              required String inputPath,
              required int quality,
              required double targetDpi,
              required void Function(int pageCount) onPageCountDetected,
              void Function(String status, double? progress)? onProgress,
            }) async {
              onPageCountDetected(1);
              onProgress?.call('Optimizing page 1 of 1...', 0.5);
              final recompressedJpg = Uint8List.fromList(
                img.encodeJpg(testImg, quality: quality),
              );
              final rebuilt = pw.Document();
              rebuilt.addPage(
                pw.Page(
                  pageFormat: p.PdfPageFormat.a4,
                  margin: pw.EdgeInsets.zero,
                  build: (context) => pw.FullPage(
                    ignoreMargins: true,
                    child: pw.Image(
                      pw.MemoryImage(recompressedJpg),
                      fit: pw.BoxFit.fill,
                    ),
                  ),
                ),
              );
              return Uint8List.fromList(await rebuilt.save());
            },
      );

      final stages = <String>[];
      final result = await service.compressPdf(
        inputPath: tempInput.path,
        quality: 60,
        outputDirectory: tempDir.path,
        onProgress: (status, progress) {
          stages.add(status);
        },
      );

      expect(result.fileSizeBytes, lessThan(result.originalSizeBytes));
      expect(result.isAlreadyOptimal, isFalse);
      expect(result.reductionPercentage, greaterThan(0));
      expect(stages.isNotEmpty, isTrue);
    });

    test('preserves file and marks optimal if already smallest', () async {
      final tempDir = Directory.systemTemp.createTempSync('krocpdf_test_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: p.PdfPageFormat.a4,
          build: (context) => pw.Center(child: pw.Text('Simple text')),
        ),
      );
      final originalBytes = await pdf.save();
      final tempInput = File('${tempDir.path}/small.pdf');
      await tempInput.writeAsBytes(originalBytes);

      const service = PdfCompressionService();
      final result = await service.compressPdf(
        inputPath: tempInput.path,
        quality: 60,
        outputDirectory: tempDir.path,
      );

      expect(result.fileSizeBytes, lessThanOrEqualTo(result.originalSizeBytes));
      expect(result.isAlreadyOptimal, isTrue);
    });

    test('throws FormatException for unreadable or corrupt PDF', () async {
      final tempDir = Directory.systemTemp.createTempSync('krocpdf_test_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final corruptFile = File('${tempDir.path}/corrupt.pdf');
      await corruptFile.writeAsBytes(Uint8List.fromList([1, 2, 3, 4, 5]));

      const service = PdfCompressionService();
      await expectLater(
        () => service.compressPdf(
          inputPath: corruptFile.path,
          quality: 60,
          outputDirectory: tempDir.path,
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
