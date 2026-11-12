# Phase 5 Plan: Automated Unit & Widget Tests + Quality Gates

**Milestone:** `v1.0-merge-pdf` (Issue #22 — On-Device Merge PDF)  
**Requirements Covered:** `MRG-06`  
**Goal:** Add comprehensive unit and widget tests for `PdfMergeService`, `LocalProcessingService('merge_pdf')`, and `showPdfPasswordDialog` / `ToolFlowScreen`, and verify all quality gates pass.

---

## Tasks

### Task 5.1: Create `test/unit/pdf_merge_service_test.dart`
- Verify `MergedPdfResult.formattedSize` (`B`, `KB`, `MB`).
- Verify `PdfMergeService.mergePdfs` merges 2 multi-page PDFs inside `Isolate.run()`, preserving total page count (`2 + 3 = 5`) and page order.
- Verify `PdfMergeService` rejects non-`.pdf` files (`FormatException`) and `!= 2` files (`ArgumentError`).
- Create password-protected PDFs with `syncfusion_flutter_pdf` (`document.security.userPassword`) and verify:
  - `inspectFiles` detects 1 encrypted PDF and 2 encrypted PDFs accurately.
  - `mergePdfs` throws `PdfPasswordRequiredException` when passwords are missing.
  - `mergePdfs` throws `PdfInvalidPasswordException` with `failedFilePaths` when a wrong password is supplied.
  - `mergePdfs` succeeds when correct passwords are supplied for 1 or both encrypted PDFs.
- Verify `LocalProcessingService.process(ProcessingRequest(toolId: 'merge_pdf', ...))` returns `Success`.

### Task 5.2: Create `test/merge_pdf_flow_test.dart`
- Verify `ToolFlowScreen(toolId: 'merge_pdf')` disables `Next step` when `< 2` PDFs are selected.
- Verify `showPdfPasswordDialog` for **1 encrypted PDF** displays 1 password field with the file name and returns the entered password.
- Verify `showPdfPasswordDialog` for **2 encrypted PDFs** displays **2 vertically stacked password fields** in one dialog with both file names (`PDF 1: ...`, `PDF 2: ...`), displays per-file error text when `fileErrors` is provided, and returns both passwords on submit.

### Task 5.3: Quality Gates
- Run `dart format .`
- Run `flutter analyze --fatal-infos --fatal-warnings`
- Run `flutter test test/unit/pdf_merge_service_test.dart test/merge_pdf_flow_test.dart`

