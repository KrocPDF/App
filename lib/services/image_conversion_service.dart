import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../features/files/data/files_repository.dart';

class ConvertedImageResult {
  final String outputPath;
  final String fileName;
  final String format;
  final int fileSizeBytes;
  final int originalSizeBytes;

  const ConvertedImageResult({
    required this.outputPath,
    required this.fileName,
    required this.format,
    required this.fileSizeBytes,
    required this.originalSizeBytes,
  });

  String get formattedSize => _formatSize(fileSizeBytes);
  String get formattedOriginalSize => _formatSize(originalSizeBytes);

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class ImageConversionService {
  const ImageConversionService();

  static const List<String> supportedInputFormats = [
    'HEIC',
    'HEIF',
    'JPG',
    'JPEG',
    'PNG',
    'WEBP',
  ];

  static const List<String> supportedOutputFormats = [
    'JPG',
    'PNG',
    'HEIC',
    'WEBP',
  ];

  static bool isHeic(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.heic') || lower.endsWith('.heif');
  }

  static String detectFormat(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.heic')) return 'HEIC';
    if (lower.endsWith('.heif')) return 'HEIF';
    if (lower.endsWith('.png')) return 'PNG';
    if (lower.endsWith('.webp')) return 'WEBP';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'JPG';
    return 'UNKNOWN';
  }

  /// Converts an image to the requested targetFormat ('JPG', 'PNG', 'HEIC', 'WEBP').
  /// Uses platform-native decoding/encoding via FlutterImageCompress for HEIC/HEIF,
  /// with a pure Dart fallback for standard formats.
  Future<ConvertedImageResult> convertImage({
    required String inputPath,
    required String targetFormat,
    int quality = 92,
  }) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw FileSystemException('Input image file does not exist', inputPath);
    }

    final originalSizeBytes = await inputFile.length();
    final normalizedTarget = targetFormat.trim().toUpperCase();

    // Determine target extension and CompressFormat
    final String targetExt;
    final CompressFormat compressFormat;

    switch (normalizedTarget) {
      case 'PNG':
        targetExt = 'png';
        compressFormat = CompressFormat.png;
        break;
      case 'HEIC':
      case 'HEIF':
        targetExt = 'heic';
        compressFormat = CompressFormat.heic;
        break;
      case 'WEBP':
        targetExt = 'webp';
        compressFormat = CompressFormat.webp;
        break;
      case 'JPG':
      case 'JPEG':
      default:
        targetExt = 'jpg';
        compressFormat = CompressFormat.jpeg;
        break;
    }

    // Prepare output directory in KrocPDF_Documents folder
    final appDocsDir = await getApplicationDocumentsDirectory();
    final outputDir = Directory('${appDocsDir.path}/${FilesRepository.documentsFolder}');
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    final originalBaseName = inputPath.split(Platform.pathSeparator).last.split('/').last;
    final dotIndex = originalBaseName.lastIndexOf('.');
    final baseNameWithoutExt = dotIndex > 0
        ? originalBaseName.substring(0, dotIndex)
        : originalBaseName;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final targetPath = '${outputDir.path}/${baseNameWithoutExt}_converted_$timestamp.$targetExt';

    // 1. Primary path: Use native platform image compression/decoding
    XFile? resultFile;
    try {
      resultFile = await FlutterImageCompress.compressAndGetFile(
        inputPath,
        targetPath,
        format: compressFormat,
        quality: quality.clamp(1, 100),
      );
    } catch (_) {
      resultFile = null;
    }

    // 2. Fallback path: If platform conversion returned null and it's not HEIC, try Dart package:image
    if (resultFile == null && !isHeic(inputPath) && normalizedTarget != 'HEIC') {
      try {
        final bytes = await inputFile.readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded != null) {
          final List<int> encoded;
          if (normalizedTarget == 'PNG') {
            encoded = img.encodePng(decoded);
          } else if (normalizedTarget == 'WEBP') {
            // ignore: deprecated_member_use
            encoded = img.encodeJpg(decoded, quality: quality);
          } else {
            encoded = img.encodeJpg(decoded, quality: quality);
          }
          final fallbackFile = File(targetPath);
          await fallbackFile.writeAsBytes(encoded);
          resultFile = XFile(targetPath);
        }
      } catch (e) {
        throw Exception('Failed to convert image: $e');
      }
    }

    if (resultFile == null) {
      throw Exception('Could not convert image to $normalizedTarget format.');
    }

    final outputFile = File(resultFile.path);
    final finalSize = await outputFile.length();

    return ConvertedImageResult(
      outputPath: outputFile.path,
      fileName: outputFile.uri.pathSegments.last,
      format: normalizedTarget,
      fileSizeBytes: finalSize,
      originalSizeBytes: originalSizeBytes,
    );
  }
}
