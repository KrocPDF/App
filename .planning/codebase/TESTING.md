# Testing Strategy & Guidelines

## Current Test Architecture
Tests reside in the `test/` directory and are structured as follows:
- **Unit Tests (`test/unit/`):**
  - `app_limits_test.dart`: Validates size limits, boundaries, and string formatting helpers.
  - `image_conversion_service_test.dart`: Validates image formats, mime types, and conversion logic.
  - `scanned_document_test.dart`: Validates scanned document entity states, pages, and metadata.
- **Widget Tests (`test/`):**
  - `files_screen_test.dart`: Validates files screen list view, empty states, and action triggers.
  - `widget_test.dart`: High-level app smoke tests and navigation verification.

## Testing Standards
1. **Deterministic Test Execution:**
   - Tests must run offline without external network requirements.
2. **Mocking & Fake Services:**
   - Override Riverpod providers using `ProviderScope(overrides: [...])` to provide mock implementations of `ProcessingService` or file services.
3. **Execution Commands:**
   - Static analysis: `flutter analyze`
   - Run full test suite: `flutter test`

