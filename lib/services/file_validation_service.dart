import '../core/constants/app_limits.dart';
import '../core/errors/app_error.dart';
import '../core/result/result.dart';

abstract class FileValidationService {
  Result<bool, AppError> validateSizeBytes(int bytes);
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
}
