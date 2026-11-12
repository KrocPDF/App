# Project State

## Current Position
- **Active Branch:** `feature/merge-pdf-22` (branched from `origin/launching_screen_fix`)
- **Active Milestone:** `v1.0-merge-pdf` (Issue #22 — On-Device Merge PDF)
- **Current Phase:** Phase 5 Complete (All `v1.0-merge-pdf` phases 3–5 complete & verified on `feature/merge-pdf-22`)
- **Previous Phases:** Phase 1, Phase 2, Phase 3, Phase 4 & Phase 5 Complete

## Key Decisions for `v1.0-merge-pdf`
- `merge_pdf` accepts strictly **two PDFs** (`.pdf` only, no images).
- Password-protected PDFs trigger a prompt rather than failing immediately: 1 password field (showing filename) when 1 PDF is encrypted, or 2 vertically stacked password fields in one window (showing both filenames) when both PDFs are encrypted.
- Phase numbering continues forward (Phase 3 -> Phase 4 -> Phase 5).
