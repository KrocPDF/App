import 'package:flutter_test/flutter_test.dart';
import 'package:krocpdf/services/image_conversion_service.dart';

void main() {
  group('ImageConversionService format detection and support', () {
    test('supports HEIC in input and output format lists', () {
      expect(ImageConversionService.supportedInputFormats, contains('HEIC'));
      expect(ImageConversionService.supportedOutputFormats, contains('HEIC'));
    });

    test('detects HEIC and HEIF extensions correctly', () {
      expect(ImageConversionService.isHeic('photo.HEIC'), isTrue);
      expect(ImageConversionService.isHeic('image.heif'), isTrue);
      expect(ImageConversionService.isHeic('test.jpg'), isFalse);
      expect(ImageConversionService.isHeic('test.png'), isFalse);
    });

    test('detectFormat detects extensions case-insensitively', () {
      expect(
        ImageConversionService.detectFormat('IMG_001.heic'),
        equals('HEIC'),
      );
      expect(
        ImageConversionService.detectFormat('IMG_002.HEIF'),
        equals('HEIF'),
      );
      expect(ImageConversionService.detectFormat('IMG_003.png'), equals('PNG'));
      expect(
        ImageConversionService.detectFormat('IMG_004.jpeg'),
        equals('JPG'),
      );
      expect(
        ImageConversionService.detectFormat('IMG_005.webp'),
        equals('WEBP'),
      );
      expect(
        ImageConversionService.detectFormat('file.unknown'),
        equals('UNKNOWN'),
      );
    });

    test('ConvertedImageResult formats sizes properly', () {
      const res = ConvertedImageResult(
        outputPath: '/path/to/test.jpg',
        fileName: 'test.jpg',
        format: 'JPG',
        fileSizeBytes: 2048,
        originalSizeBytes: 1048576,
      );

      expect(res.formattedSize, equals('2.0 KB'));
      expect(res.formattedOriginalSize, equals('1.00 MB'));
    });
  });
}
