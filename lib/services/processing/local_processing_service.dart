import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as p;
import 'package:pdf/widgets.dart' as pw;

import '../../core/errors/app_error.dart';
import '../../core/result/result.dart';
import '../../features/files/data/files_repository.dart';
import '../../features/tool_flow/domain/scanned_document.dart';
import '../image_conversion_service.dart';
import 'processing_service.dart';

class LocalProcessingService implements ProcessingService {
  const LocalProcessingService();

  @override
  Future<Result<ProcessingResult, AppError>> process(
    ProcessingRequest request,
  ) async {
    if (request.toolId == 'image_to_pdf' || request.toolId == 'scan_to_pdf') {
      try {
        final pages = request.filePaths.asMap().entries.map((e) {
          return ScannedPage(id: 'page_${e.key}', originalPath: e.value);
        }).toList();

        final outputPath = await compilePagesToPdf(
          pages: pages,
          outputFileName: 'output.pdf',
        );

        return Success(
          ProcessingResult(
            outputFilePath: outputPath,
            message: 'PDF generated successfully.',
          ),
        );
      } catch (e) {
        return Failure(ProcessingFailed(reason: 'Failed to create PDF: $e'));
      }
    }

    if (request.toolId == 'image_convert') {
      try {
        if (request.filePaths.isEmpty) {
          return const Failure(
            ProcessingFailed(reason: 'No input image provided for conversion.'),
          );
        }
        final targetFormat = request.format ?? 'JPG';
        const converter = ImageConversionService();
        final result = await converter.convertImage(
          inputPath: request.filePaths.first,
          targetFormat: targetFormat,
        );
        return Success(
          ProcessingResult(
            outputFilePath: result.outputPath,
            message: 'Image converted to ${result.format} successfully.',
          ),
        );
      } catch (e) {
        return Failure(ProcessingFailed(reason: 'Failed to convert image: $e'));
      }
    }

    return const Failure(
      ProcessingFailed(
        reason: 'Local on-device processing not implemented yet.',
      ),
    );
  }

  /// Compiles a list of ScannedPage objects into a single PDF document.
  /// Runs heavy operations inside Isolate.run() off the main thread.
  Future<String> compilePagesToPdf({
    required List<ScannedPage> pages,
    required String outputFileName,
  }) async {
    // 1. Preprocess HEIC/HEIF files natively on main thread if encountered
    final rawDataList = <Map<String, dynamic>>[];
    for (final page in pages) {
      final path = page.activeFilePath;
      Uint8List? preloadedBytes;
      if (path.toLowerCase().endsWith('.heic') ||
          path.toLowerCase().endsWith('.heif')) {
        try {
          preloadedBytes = await FlutterImageCompress.compressWithFile(
            path,
            format: CompressFormat.jpeg,
            quality: 92,
          );
        } catch (_) {}
      }
      rawDataList.add({
        'path': path,
        'bytes': preloadedBytes,
        'rotation': page.rotationDegrees,
        'filter': page.filter.name,
      });
    }

    // 2. Offload raster transformations and PDF compilation to a dedicated background Isolate
    final pdfBytes = await Isolate.run(() => _isolateCompilePdf(rawDataList));

    // 3. Write output file to persistent KrocPDF_Documents directory
    final appDocsDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(
      '${appDocsDir.path}/${FilesRepository.documentsFolder}',
    );
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final sanitizedName = outputFileName.endsWith('.pdf')
        ? outputFileName
        : '$outputFileName.pdf';
    final outputFile = File('${targetDir.path}/$sanitizedName');
    await outputFile.writeAsBytes(pdfBytes);

    return outputFile.path;
  }
}

/// Top-level isolate worker for compiling PDF without freezing UI
Future<Uint8List> _isolateCompilePdf(
  List<Map<String, dynamic>> pageDataList,
) async {
  final pdfDocument = pw.Document();

  for (final data in pageDataList) {
    Uint8List? imageBytes = data['bytes'] as Uint8List?;
    final filePath = data['path'] as String;
    final rotation = data['rotation'] as int? ?? 0;
    final filterName = data['filter'] as String? ?? 'original';

    if (imageBytes == null) {
      final file = File(filePath);
      if (file.existsSync()) {
        imageBytes = file.readAsBytesSync();
      } else {
        final placeholder = img.Image(width: 200, height: 200);
        img.fill(placeholder, color: img.ColorRgb8(240, 240, 240));
        imageBytes = Uint8List.fromList(img.encodeJpg(placeholder));
      }
    }

    // Apply rotation or filter via package:image if specified
    if (rotation != 0 || filterName != 'original') {
      final decoded = img.decodeImage(imageBytes);
      if (decoded != null) {
        img.Image transformed = decoded;
        if (rotation != 0) {
          transformed = img.copyRotate(transformed, angle: rotation);
        }
        if (filterName == 'grayscale') {
          transformed = img.grayscale(transformed);
        } else if (filterName == 'blackAndWhite') {
          transformed = img.grayscale(transformed);
          for (final pixel in transformed) {
            final lum = pixel.r.toInt();
            final val = lum > 128 ? 255 : 0;
            pixel.r = val;
            pixel.g = val;
            pixel.b = val;
          }
        }
        imageBytes = Uint8List.fromList(
          img.encodeJpg(transformed, quality: 90),
        );
      }
    }

    final memoryImage = pw.MemoryImage(imageBytes);
    pdfDocument.addPage(
      pw.Page(
        pageFormat: p.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Image(memoryImage, fit: pw.BoxFit.contain),
          );
        },
      ),
    );
  }

  return await pdfDocument.save();
}
