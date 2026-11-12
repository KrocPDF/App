# System & Project Requirements

## Non-Negotiable Rules
1. **Privacy-First (Confidential Mode):** Zero remote network calls during standard on-device conversions and document operations.
2. **Strict Limit Enforcement:** All local operations abide by `AppLimits.maxLocalFileBytes` (100 MB).
3. **Monochrome Aesthetic:** Maintain strict high-contrast theme conventions without arbitrary accent colors.
4. **Deterministic Quality Gates:** Every PR must pass static analysis (`flutter analyze`) and automated test suites (`flutter test`) without warnings or errors.

## Active Milestone Requirements: `v1.0-merge-pdf` (Issue #22)
- **MRG-01 (PDF-Only Two-File Input):** `merge_pdf` accepts strictly two PDF files (`.pdf` only, no images) and validates file existence and size limits.
- **MRG-02 (Reordering & Naming):** Users can reorder the two selected PDFs and optionally specify an output filename before merging.
- **MRG-03 (On-Device Isolate Merge):** `PdfMergeService` merges the PDFs strictly on-device via `syncfusion_flutter_pdf` inside `Isolate.run()`, preserving page sizes/orientations and disposing all `PdfDocument` resources in `try/finally`.
- **MRG-04 (Password-Protected PDF Handling):** Before failing on encryption, detect whether 1 or both selected PDFs are password-protected:
  - If **one** PDF is encrypted, prompt for a single password clearly displaying that file's name.
  - If **both** PDFs are encrypted, show **one** dialog with two vertically stacked password fields (labeled with each file's name) so the user can enter both passwords together.
  - Wrong passwords show inline validation and allow retry without resetting the flow.
- **MRG-05 (Progress, Result & File Actions):** `ToolFlowScreen` shows merge progress, resulting page count/file size, and supports **Save to Files**, **Share**, and **Open in Viewer**.
- **MRG-06 (Automated Tests):** Unit tests cover multi-PDF merge, page count & order preservation, password-protected PDF unlocking, and invalid/missing file errors; widget tests cover 2-PDF selection, password prompt rendering (1 vs 2 files), and flow navigation.
