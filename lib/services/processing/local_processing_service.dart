import '../../core/errors/app_error.dart';
import '../../core/result/result.dart';
import 'processing_service.dart';

class LocalProcessingService implements ProcessingService {
  const LocalProcessingService();

  @override
  Future<Result<ProcessingResult, AppError>> process(ProcessingRequest request) {
    throw UnimplementedError('Local on-device processing not implemented yet.');
  }
}
