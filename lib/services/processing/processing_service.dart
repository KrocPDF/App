import '../../core/errors/app_error.dart';
import '../../core/result/result.dart';

class ProcessingRequest {
  final String toolId;
  final String? format;
  final List<String> filePaths;

  const ProcessingRequest({
    required this.toolId,
    this.format,
    this.filePaths = const [],
  });
}

class ProcessingResult {
  final String outputFilePath;
  final String message;

  const ProcessingResult({
    required this.outputFilePath,
    this.message = 'Processing completed successfully.',
  });
}

abstract class ProcessingService {
  Future<Result<ProcessingResult, AppError>> process(ProcessingRequest request);
}
