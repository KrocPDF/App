# Roadmap & Milestones

## Completed Milestone: Repository Health, Governance & CI/CD
- **Phase 1: Codebase Mapping & Project Initialization** (Done)
- **Phase 2: CI/CD Workflows & Governance Documentation** (Done — PR #2)

## Active Milestone: `v1.0-merge-pdf` — On-Device Merge PDF (Issue #22)
- **Goal:** Implement on-device two-PDF merging via `syncfusion_flutter_pdf` in `Isolate.run()`, including unified 1-or-2-file password prompt handling and full unit/widget test coverage.
- **Phases:**
  - **Phase 3: Merge Engine, Encryption Detection & Isolate Pipeline** (Done)
    - Implement `PdfMergeService` (`mergePdfs`, `detectProtectedPdfs`) using `syncfusion_flutter_pdf` inside `Isolate.run()` with `try/finally` disposal.
    - Support optional per-file passwords (`Map<String, String> passwords`) for encrypted PDFs.
    - Wire `merge_pdf` in `LocalProcessingService.process(...)`.
  - **Phase 4: Tool Flow UI, Two-PDF Selection & Unified Password Prompt** (Done)
    - Enforce strictly two PDFs (`.pdf` only) in `_buildMergePdfSelectStep` with reorder/swap/remove controls.
    - Implement unified password modal/dialog: 1 field (with filename) if 1 PDF is encrypted; 2 stacked fields (each with filename) if both PDFs are encrypted, with inline wrong-password retry.
    - Wire progress state, custom output filename, and Result actions (Save to Files, Share, Open in Viewer).
  - **Phase 5: Automated Unit & Widget Tests + Quality Gates** (Done)
    - Add `test/unit/pdf_merge_service_test.dart` (merge accuracy, page order, encrypted PDF unlock/wrong-password, corrupt/missing file errors).
    - Add widget tests for `ToolFlowScreen(toolId: 'merge_pdf')` (2-PDF gating, 1-file & 2-file password dialogs).
    - Verify `dart format .`, `flutter analyze --fatal-infos --fatal-warnings`, and `flutter test`.

## Upcoming Milestones (Google Play Launch Track)
- **M1:** Remaining v1.0 Feature Completeness & Polish (`#23`, `#24`, `#25`, `#26`)
- **M2:** Android Release Build & Security Hardening (`#33`, `#27`, `#28`, `#29`)
- **M3:** Legal, Privacy & Play Console Compliance (`#30`, `#31`, `#32`)
- **M4:** Store Listing, Closed Testing & Launch (`#34`, `#35`, `#36`)
