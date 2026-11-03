import 'package:flutter_test/flutter_test.dart';
import 'package:krocpdf/core/constants/app_limits.dart';
import 'package:krocpdf/services/file_validation_service.dart';

void main() {
  group('AppLimits', () {
    test('maxLocalFileBytes is exactly 100 MB', () {
      const expectedBytes = 100 * 1024 * 1024;
      expect(AppLimits.maxLocalFileBytes, equals(expectedBytes));
      expect(AppLimits.maxLocalFileBytes, equals(104857600));
    });

    test('formattedLimitMb returns 100 MB', () {
      expect(AppLimits.formattedLimitMb, equals('100 MB'));
    });

    test('FileValidationService rejects files exceeding limit', () {
      const validator = LocalFileValidationService();
      final validResult = validator.validateSizeBytes(
        AppLimits.maxLocalFileBytes,
      );
      expect(validResult.isSuccess, isTrue);

      final oversizedResult = validator.validateSizeBytes(
        AppLimits.maxLocalFileBytes + 1,
      );
      expect(oversizedResult.isFailure, isTrue);
      expect(oversizedResult.errorOrNull?.message, contains('100 MB'));
    });
  });
}
