import '../../core/errors/app_error.dart';
import '../../core/result/result.dart';
import '../pdf_split_service.dart';

class ProcessingRequest {
  final String toolId;
  final String? format;
  final List<String> filePaths;
  final Map<String, String> passwords;
  final String? outputFileName;
  final List<SplitGroup>? splitGroups;

  const ProcessingRequest({
    required this.toolId,
    this.format,
    this.filePaths = const [],
    this.passwords = const {},
    this.outputFileName,
    this.splitGroups,
  });
}

class ProcessingResult {
  final String outputFilePath;
  final List<String> outputFilePaths;
  final String message;
  final SplitPdfResult? splitResult;

  const ProcessingResult({
    required this.outputFilePath,
    this.outputFilePaths = const [],
    this.message = 'Processing completed successfully.',
    this.splitResult,
  });
}

abstract class ProcessingService {
  Future<Result<ProcessingResult, AppError>> process(ProcessingRequest request);
}
