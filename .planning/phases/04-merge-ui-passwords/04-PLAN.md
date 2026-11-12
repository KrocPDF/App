# Phase 4 Plan: Tool Flow UI, Two-PDF Selection & Unified Password Prompt

**Milestone:** `v1.0-merge-pdf` (Issue #22 — On-Device Merge PDF)  
**Requirements Covered:** `MRG-01`, `MRG-02`, `MRG-04`, `MRG-05`  
**Goal:** Wire `merge_pdf` end-to-end in `ToolFlowScreen` with strictly 2-PDF selection & reordering, a unified 1-or-2-file password prompt dialog, progress tracking, and Save/Share/View result actions.

---

## Tasks

### Task 4.1: Enforce Strictly Two PDFs & Reordering in `ToolFlowScreen`
- Update `lib/features/tool_flow/presentation/tool_flow_screen.dart`:
  - Add `bool get _isMergePdf => widget.toolId == 'merge_pdf';` and merge state fields (`_mergeOutputNameController`, `_isMerging`, `_mergeStage`, `_mergeProgress`, `_mergeError`, `_mergeResult`, `_isMergedSavedToFiles`, `_isSavingMergedPdf`).
  - Enforce `canGoNext` on step 0 for `_isMergePdf` as `_selectedFiles.length == 2`.
  - Cap `_selectedFiles` to 2 `.pdf` files when picking from device or Saved Files (showing a SnackBar if >2 are picked).
  - Enhance `_buildMergePdfSelectStep` to show `X of 2 PDFs selected`, a **Swap Order** button when 2 PDFs are selected, and disable/hide Add buttons once 2 PDFs are selected.

### Task 4.2: Create `lib/features/tool_flow/presentation/widgets/pdf_password_dialog.dart`
- Build `showPdfPasswordDialog(...)`:
  - Accepts `List<String> encryptedFilePaths`, optional `Map<String, String>? initialPasswords`, and optional `Map<String, String>? fileErrors`.
  - **Single encrypted PDF:** Renders 1 password field clearly labeled with the file's name and visibility toggle.
  - **Two encrypted PDFs:** Renders **one dialog** with 2 vertically stacked (up-and-down) password fields, each labeled with its file's name, visibility toggle, and per-file inline error message if retrying after a wrong password.
  - Validates non-empty entries and returns `Map<String, String>` on submit or `null` on cancel.

### Task 4.3: Merge Options, Progress, Password-Retry & Result Steps in `ToolFlowScreen`
- Add `_isMergePdf` step routing in `_buildStepContent` (and bottom bar visibility matching `_isCompressPdf`).
- `_buildMergePdfOptionsStep`: Shows ordered PDF #1 & #2 preview with Swap button, optional output filename input, and **Merge PDF** action button.
- `_startMerge`:
  - Calls `PdfMergeService().inspectFiles(...)`.
  - Prompts via `showPdfPasswordDialog(...)` if 1 or 2 PDFs are encrypted.
  - Calls `PdfMergeService().mergePdfs(...)`; on `PdfInvalidPasswordException` or `PdfPasswordRequiredException`, re-opens the dialog with per-file error messages so the user can retry without failing out of the flow.
- `_buildMergePdfProgressStep` & `_buildMergePdfResultStep`:
  - Progress indicator + error retry state.
  - Result card showing `fileName`, `totalPageCount`, `formattedSize`, plus **Save to Files** (in-flight guarded), **Share**, **Open in Viewer**, and **Merge Another**.

---

## Verification Plan
- `C:\Users\HP\flutter\bin\dart.bat format lib/features/tool_flow/`
- `C:\Users\HP\flutter\bin\flutter.bat analyze --fatal-infos --fatal-warnings`

