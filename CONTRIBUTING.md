# Contributing to KrocPDF Mobile

Thank you for your interest in contributing to KrocPDF! We are building a high-performance, privacy-focused, cross-platform PDF and document toolkit.

---

## 1. Code of Conduct

All contributors are expected to uphold our [Code of Conduct](CODE_OF_CONDUCT.md). Please report any violations to conduct@krocpdf.com.

---

## 2. Pinned Development Toolchain

To ensure deterministic builds and parity with our CI pipeline:
- **Flutter SDK:** `3.44.6` (channel stable)
- **Dart SDK:** `3.12.2`
- **Java:** JDK 17 (Zulu distribution recommended)
- **Android Target:** `minSdk = 24`, `targetSdk = 35`

Check your local environment:
```bash
flutter --version
dart --version
```

---

## 3. Getting Started

1. **Fork or Clone the Repository:**
   ```bash
   git clone https://github.com/KrocPDF/App.git
   cd App
   ```

2. **Install Dependencies:**
   ```bash
   flutter pub get
   ```

3. **Verify Local Setup:**
   ```bash
   flutter analyze
   flutter test
   ```

---

## 4. Architectural Rules & Principles

Before writing code, please review [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and [`docs/DECISIONS.md`](docs/DECISIONS.md):
1. **Privacy-First (Confidential Mode):** No network requests or remote data transmissions for standard document processing.
2. **File Size Limits:** Always respect `AppLimits.maxLocalFileBytes` (100 MB). Never hardcode magic file sizes.
3. **Monochrome Design System:** Follow the strict monochrome theme defined in `core/theme/app_theme.dart` (zero accent colors, 1px borders, 8px grid).
4. **State Management & Routing:** Use `flutter_riverpod` for state management and `go_router` for navigation.

---

## 5. Development Workflow

1. Create a descriptive feature or fix branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/issue-description
   ```

2. Run automated formatters and linters:
   ```bash
   dart format .
   flutter analyze --fatal-infos
   ```

3. Run automated tests:
   ```bash
   flutter test --coverage
   ```

4. Commit using conventional commit format:
   - `feat: add PDF encryption support`
   - `fix: correct file size rounding in settings`
   - `docs: update contribution guidelines`

---

## 6. Pull Request Checklist

Before submitting your PR, ensure:
- [ ] Code is formatted with `dart format .`.
- [ ] `flutter analyze` reports zero errors, warnings, or infos.
- [ ] All unit and widget tests in `test/` pass cleanly.
- [ ] New functionality is covered with unit/widget tests.
- [ ] Any architectural changes are documented in `docs/DECISIONS.md`.
