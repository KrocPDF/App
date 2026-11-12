# Changelog

All notable changes to the KrocPDF Mobile project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Branded launch animation sequence (`LaunchAnimationScreen` and `LaunchGate`) featuring paper drop, conversion to PDF document, crocodile bite interaction, carrier motion, and trail reveal into the KrocPDF wordmark.
- Wall-clock monotonic `Stopwatch` + `Ticker` timing engine ensuring a consistent 4.2-second launch pacing across all display refresh rates (60Hz, 90Hz, 120Hz).
- Adaptive monochrome dark-mode document styling ensuring high-contrast teeth and jaw silhouette visibility across both light and dark themes.
- On-device PDF compression engine (`PdfCompressionService`) with quality presets and custom slider.
- Multi-tier GitHub Actions CI/CD pipeline (`pr-checks.yml`, `release-checks.yml`, `release-drafter.yml`).
- PR validation check for Release Notes / Changelog entry updates.
- Standard open-source governance suite (`LICENSE`, `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`).
- GitHub issue forms (`bug_report.yml`, `feature_request.yml`, `documentation.yml`, `config.yml`).
- Structured pull request template (`PULL_REQUEST_TEMPLATE.md`).
- Project planning and codebase intelligence architecture under `.planning/`.
- Core Flutter application scaffolding with strict monochrome design system (Light & Dark modes).
- Confidential Mode (100% on-device local document processing up to 100 MB).
- Declarative routing with `go_router` and persistent shell navigation.
- ML Kit document scanning integration with edge detection and multi-page capture.
- Image conversion pipeline supporting JPG, PNG, HEIC, and WEBP formats.
- Local persistent file management (save, view, share, print, and delete).
- Native splash screens with official KrocPDF branding.

### Fixed
- ML Kit document scanner with auto-capture and native file edit flows.
