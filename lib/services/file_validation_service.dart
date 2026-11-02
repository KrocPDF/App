import 'dart:io';
import '../core/constants/app_limits.dart';
import '../core/errors/app_error.dart';
import '../core/result/result.dart';

abstract class FileValidationService {
  Result<bool, AppError> validateSizeBytes(int bytes);
  Result<bool, AppError> validateExtension(String filePath, List<String> allowedExtensions);
  Result<bool, AppError> validateFile(File file, {List<String>? allowedExtensions});
}

class LocalFileValidationService implements FileValidationService {
  const LocalFileValidationService();

  @override
  Result<bool, AppError> validateSizeBytes(int bytes) {
    if (bytes > AppLimits.maxLocalFileBytes) {
      return Failure(FileTooLarge(fileSizeBytes: bytes));
    }
    return const Success(true);
  }

  @override
  Result<bool, AppError> validateExtension(String filePath, List<String> allowedExtensions) {
    final normalizedAllowed = allowedExtensions
        .map((e) => e.toLowerCase().replaceAll('.', ''))
        .toSet();

    final ext = filePath.contains('.')
        ? filePath.split('.').last.toLowerCase()
        : '';

    if (ext.isEmpty || !normalizedAllowed.contains(ext)) {
      return Failure(UnsupportedType(fileExtension: ext.isNotEmpty ? ext : 'unknown'));
    }
    return const Success(true);
  }

  @override
  Result<bool, AppError> validateFile(File file, {List<String>? allowedExtensions}) {
    if (!file.existsSync()) {
      return const Failure(ProcessingFailed(reason: 'Selected file does not exist.'));
    }

    if (allowedExtensions != null && allowedExtensions.isNotEmpty) {
      final extResult = validateExtension(file.path, allowedExtensions);
      if (extResult is Failure<bool, AppError>) {
        return extResult;
      }
    }

    final length = file.lengthSync();
    return validateSizeBytes(length);
  }
}
