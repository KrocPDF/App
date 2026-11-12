# KrocPDF App Project Specification

## Project Overview
- **Name:** KrocPDF App
- **Description:** The official cross-platform mobile companion application for the KrocPDF suite (privacy-first file converter and PDF toolkit).
- **Core Philosophy:** Privacy-by-design, Confidential Mode with local on-device processing up to 100 MB, clean monochrome interface.

## Target Audience & Platforms
- **Primary Platforms:** Android (minSdk 24, targetSdk 35), iOS (target 13.0).
- **Secondary / Preview Platform:** Web (preview on Brave/Chrome).

## Core Capabilities
- On-device document scanning with automatic edge capture (ML Kit).
- PDF toolkit: merge, split, view, convert, edit, and compress.
- Image conversion and editing (JPG, PNG, HEIC, WEBP).
- Local persistent file management (save, view, share, print, delete).

## Current Milestone: v1.0-merge-pdf — On-Device Merge PDF (#22)
**Goal:** Deliver a reliable, isolate-offloaded, on-device Merge PDF pipeline using `syncfusion_flutter_pdf`, supporting two PDFs (no images) with interactive password-unlock prompts for encrypted inputs.

**Target features:**
- Two-PDF selection, reordering, and validation (PDFs only).
- On-device merge engine (`PdfMergeService` + `LocalProcessingService`) running in `Isolate.run()`.
- Unified password prompt dialog supporting 1 or 2 password-protected PDFs with per-file labels.
- Progress, Save to Files, Share, and Open in Viewer actions in `ToolFlowScreen`.

## Evolution
This document evolves at phase transitions and milestone boundaries.
- Last updated: 2026-11-12 (Initialized `v1.0-merge-pdf` milestone for Issue #22)

