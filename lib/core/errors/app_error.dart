import '../constants/app_limits.dart';

/// Sealed hierarchy representing domain-level processing and validation errors.
sealed class AppError {
  const AppError();

  /// User-facing calm and concise error message.
  String get message;
}

final class FileTooLarge extends AppError {
  final int fileSizeBytes;
  final int maxBytes;

  const FileTooLarge({
    required this.fileSizeBytes,
    this.maxBytes = AppLimits.maxLocalFileBytes,
  });

  @override
  String get message => 'This file is larger than ${AppLimits.formattedLimitMb}.';
}

final class UnsupportedType extends AppError {
  final String fileExtension;

  const UnsupportedType({required this.fileExtension});

  @override
  String get message => 'This format (.$fileExtension) is not supported.';
}

final class InsufficientStorage extends AppError {
  final int requiredBytes;

  const InsufficientStorage({required this.requiredBytes});

  @override
  String get message => 'Not enough storage space on your device.';
}

final class ProcessingFailed extends AppError {
  final String reason;

  const ProcessingFailed({this.reason = 'An unexpected error occurred during processing.'});

  @override
  String get message => reason;
}

final class Cancelled extends AppError {
  const Cancelled();

  @override
  String get message => 'Operation was cancelled.';
}
