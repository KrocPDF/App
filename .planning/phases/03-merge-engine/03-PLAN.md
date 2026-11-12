# Phase 3 Plan: Merge Engine, Encryption Detection & Isolate Pipeline

**Milestone:** `v1.0-merge-pdf` (Issue #22 — On-Device Merge PDF)  
**Requirements Covered:** `MRG-01`, `MRG-03`, `MRG-04` (backend/service layer)  
**Goal:** Build `PdfMergeService` with `syncfusion_flutter_pdf` inside `Isolate.run()`, supporting strictly two `.pdf` inputs, per-file encryption detection, password unlocking/retry errors, and `LocalProcessingService` integration.

---

## Verification & Research Notes
- `syncfusion_flutter_pdf: ^35.1.42` is already in `pubspec.yaml` and supports `PdfDocument(inputBytes: bytes, password: password)` and `page.createTemplate()` for lossless vector/text page copying across mixed page sizes.
- `AppLimits.maxLocalFileBytes` (100 MB) is enforced in `lib/core/constants/app_limits.dart`.
- `ProcessingRequest` in `lib/services/processing/processing_service.dart` can accept optional `passwords` and `outputFileName` named parameters without breaking any existing callers.

---

## Tasks

### Task 3.1: Create `lib/services/pdf_merge_service.dart`
- **Models & Typed Exceptions:**
  - `MergedPdfResult` (`outputPath`, `fileName`, `fileSizeBytes`, `totalPageCount`, `sourcePageCounts`, `formattedSize`).
  - `PdfEncryptionCheckResult` (`encryptedFilePaths`, `invalidFiles`).
  - `PdfPasswordRequiredException` (`encryptedFilePaths`, `message`).
  - `PdfInvalidPasswordException` (`failedFilePaths`, `message`).
- **Pre-flight Encryption Inspection (`inspectFiles`):**
  - Validate each input file exists, is non-empty, has `.pdf` extension (reject images/non-PDFs), and is within `AppLimits.maxLocalFileBytes`.
  - Run `Isolate.run()` to open each PDF with `sf.PdfDocument(inputBytes: bytes)` (with `try/finally` disposal).
  - Identify password-protected PDFs vs corrupt/unreadable PDFs cleanly so the UI can prompt for 1 or 2 passwords before merging.
- **Isolate Merge (`mergePdfs`):**
  - Enforce strictly 2 `.pdf` input paths (`inputPaths.length == 2`).
  - Run `Isolate.run()` to open both PDFs (passing `passwords[path]` when provided), distinguish missing password (`PdfPasswordRequiredException`) vs wrong password (`PdfInvalidPasswordException` with failing file path), copy all pages via `sourcePage.createTemplate()` preserving each page's dimensions/orientation, save bytes, and dispose all `PdfDocument` instances in `try/finally`.
  - Write merged PDF to `outputDirectory` (or `getTemporaryDirectory()`) and return `MergedPdfResult`.

### Task 3.2: Wire `merge_pdf` in `ProcessingRequest` & `LocalProcessingService`
- Update `lib/services/processing/processing_service.dart`:
  - Add optional `final Map<String, String> passwords;` (default `const {}`) and `final String? outputFileName;` to `ProcessingRequest`.
- Update `lib/services/processing/local_processing_service.dart`:
  - Handle `request.toolId == 'merge_pdf'` by invoking `const PdfMergeService().mergePdfs(...)` and returning `Success(ProcessingResult(...))` or `Failure(ProcessingFailed(...))`.

---

## Verification Plan
- `C:\Users\HP\flutter\bin\dart.bat format --output=none --set-exit-if-changed lib/services/pdf_merge_service.dart lib/services/processing/`
- `C:\Users\HP\flutter\bin\flutter.bat analyze --fatal-infos --fatal-warnings`
- Quick smoke check via `flutter test test/unit/`

