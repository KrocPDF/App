import '../../core/errors/app_error.dart';
import '../../core/result/result.dart';
import 'processing_service.dart';

class CloudProcessingService implements ProcessingService {
  const CloudProcessingService();

  @override
  Future<Result<ProcessingResult, AppError>> process(
    ProcessingRequest request,
  ) {
    throw UnimplementedError('Cloud processing not implemented yet.');
  }
}
