# Architecture Decision Records (ADR)

| ID | Title | Status | Date |
|---|---|---|---|
| D-001 | Feature-First Project Structure | Accepted | 2026-10-28 |
| D-002 | Exact Dependency Version Pinning | Accepted | 2026-10-28 |
| D-003 | Strict Monochrome Design System and Theme Overrides | Accepted | 2026-10-28 |
| D-004 | Single Source of Truth for File Size Limits | Accepted | 2026-10-28 |
| D-005 | Sealed Domain Error Hierarchy | Accepted | 2026-10-28 |
| D-006 | Abstract Processing Service Contract | Accepted | 2026-10-28 |
| D-007 | Platform Baselines: Android SDK 24 and iOS 13 with Zero Production Permissions | Accepted | 2026-10-28 |
| D-008 | State Management and Routing Choice: Riverpod and go_router | Accepted | 2026-10-28 |
| D-009 | Strict Local-Only Git Workflow (No-Push Policy) | Outdated | 2026-10-28 |
| D-010 | Pinned Flutter SDK and Dart Toolchain Baseline | Accepted | 2026-10-28 |
| D-011 | Format Parameter Passing via Route Query Parameters | Accepted | 2026-10-28 |
| D-012 | Web Platform Target for Local Browser Preview in Brave | Accepted | 2026-10-28 |
| D-013 | Native Splash Screen via Build-Time Dev Dependency | Accepted | 2026-10-28 |
| D-014 | Splash Screen Hold Duration for Visual Verification & Animation Preparation | Superseded by D-017 | 2026-10-28 |
| D-015 | Persistent Multi-Branch Navigation via StatefulShellRoute.indexedStack | Accepted | 2026-10-29 |
| D-016 | Scan-to-PDF Pipeline and Shared Multi-Page Editing Toolbar | Accepted | 2026-10-29 |
| D-017 | Native Flutter Branded Launch Animation and Cold-Start Gate | Accepted | 2026-11-04 |

---

## D-001: Feature-First Project Structure
- Date: 2026-10-28
- Change: Organized codebase into `lib/core`, `lib/features/{home, tool_flow, settings}`, and `lib/services`.
- Why: Keeps features decoupled and self-contained while sharing cross-cutting concerns (theme, limits, errors) via `core`.
- Alternatives considered: Layer-first (`screens/`, `widgets/`, `models/`). Rejected because it degrades maintainability and scalability as the number of tools grows.
- Impact: Clear boundaries between features; individual tool flows can evolve independently.
- Future impact: In Phases 2–4, new tools or formats can be integrated without modifying unrelated feature presentations.
- Status: Accepted

## D-002: Exact Dependency Version Pinning
- Date: 2026-10-28
- Change: Pinned dependencies in `pubspec.yaml` without caret (`^`) ranges (`flutter_riverpod: 2.6.1`, `go_router: 14.8.1`, `flutter_lints: 6.0.0`). Committed `pubspec.lock`.
- Why: Eliminates unexpected transitive breaking changes and guarantees reproducible, deterministic builds for a solo developer.
- Alternatives considered: Using `^` semantic version ranges. Rejected due to the risk of silent sub-dependency upgrades breaking builds.
- Impact: Fully deterministic dependency resolution across machines.
- Future impact: Package upgrades must be intentional and tested individually.
- Status: Accepted

## D-003: Strict Monochrome Design System and Theme Overrides
- Date: 2026-10-28
- Change: Configured Material 3 ThemeData with zero color accents, flat surfaces (no elevation/shadows), 1px `#E5E5E5` borders (light mode) and 1px `#2A2A2A` borders (dark mode), 6px border radii, system typography, and outlined icons.
- Why: Ensures a focused, distraction-free, utilitarian interface that prioritizes clarity, content hierarchy, and legibility.
- Alternatives considered: Stock Material 3 color palettes or third-party UI component suites. Rejected to maintain a clean, human-designed aesthetic.
- Impact: High-contrast light and dark modes with uniform spacing on an 8px grid.
- Future impact: Low-overhead design system with minimal maintenance.
- Status: Accepted

## D-004: Single Source of Truth for File Size Limits
- Date: 2026-10-28
- Change: Created `AppLimits.maxLocalFileBytes = 100 * 1024 * 1024` (100 MB) in `core/constants/app_limits.dart`.
- Why: Prevents magic numbers in UI text, validation routines, and file processing guards.
- Alternatives considered: Hardcoding "100 MB" in UI widgets or calculating dynamic limits. Rejected as error-prone and brittle.
- Impact: Settings and tool flow screens consume this single constant for validation and copy.
- Future impact: Changing the local processing ceiling requires updating exactly one constant.
- Status: Accepted

## D-005: Sealed Domain Error Hierarchy
- Date: 2026-10-28
- Change: Defined `sealed class AppError` with subtypes: `FileTooLarge`, `UnsupportedType`, `InsufficientStorage`, `ProcessingFailed`, and `Cancelled`.
- Why: Enables exhaustive switch-expression handling at the presentation layer without unchecked runtime exceptions.
- Alternatives considered: Generic `Exception` with string messages. Rejected due to lack of compile-time exhaustiveness.
- Impact: Type-safe error handling across services and UI shells.
- Future impact: Ready for integration with real file I/O and processing engines in Phase 2.
- Status: Accepted

## D-006: Abstract Processing Service Contract
- Date: 2026-10-28
- Change: Created `ProcessingService` abstract interface, implemented by `LocalProcessingService` and `CloudProcessingService` stub classes throwing `UnimplementedError`.
- Why: Decouples UI from processing execution, allowing "Confidential Mode" (local) and "Non-Confidential Mode" (cloud) to be swapped without changing tool flow controllers.
- Alternatives considered: Direct calls to local functions from UI controllers. Rejected because Phase 4 requires remote execution for Office conversion.
- Impact: Clean dependency injection boundary using Riverpod providers.
- Future impact: Phase 2 and Phase 4 provide concrete implementations to the existing interface.
- Status: Accepted

## D-007: Platform Baselines: Android SDK 24 and iOS 13 with Zero Production Permissions
- Date: 2026-10-28
- Change: Configured Android `minSdk = 24`, iOS deployment target `13.0`, application ID / bundle ID `com.krocpdf.app`, app name `KrocPDF`. Manifest requests NO runtime permissions in release builds. Debug build retains standard `android.permission.INTERNET` for Flutter tool communication. iOS is fully configured but marked unbuilt/unverified until Mac verification.
- Why: Establishes a modern OS baseline while preventing unnecessary permission prompts for an app running local processing.
- Alternatives considered: Adding storage permissions early. Rejected because Android Scoped Storage and iOS Document Picker do not require broad external storage permissions.
- Impact: Clean installation on modern devices with zero privacy prompts.
- Future impact: File picking in Phase 2 will utilize system pickers without broad storage access.
- Status: Accepted

## D-008: State Management and Routing Choice: Riverpod and go_router
- Date: 2026-10-28
- Change: Selected `flutter_riverpod: 2.6.1` for reactive state management and `go_router: 14.8.1` for declarative routing.
- Why: Riverpod provides compile-safe, testable dependency injection without BuildContext dependency; `go_router` provides clean URL-style navigation and type-safe query parameter handling.
- Alternatives considered: Provider + standard Navigator 2.0. Rejected due to boilerplate and lack of declarative route parameters.
- Impact: Clear separation between presentation state, service contracts, and navigation transitions.
- Future impact: Scales cleanly to asynchronous task queues and multi-step tool progress in subsequent phases.
- Status: Accepted

## D-009: Strict Local-Only Git Workflow (No-Push Policy)
- Date: 2026-10-28
- Status: Outdated / Superseded — Remote repository `https://github.com/KrocPDF/App` was configured per user instruction on 2026-11-03. Current development remains local on the active branch without pushing until explicitly instructed.
- Change: Verified local git repository with all remote tracking URLs removed (`git remote -v` outputs empty). Established atomic local commits after each verified step.
- Why: Guarantees zero unintentional data or code leaks to external servers during development.
- Alternatives considered: Maintaining a disabled remote. Rejected in favor of an empty remote list to make accidental pushes physically impossible.
- Impact: Commits are strictly local on the current branch until explicit user instruction.
- Future impact: Pushes require explicit user approval.

## D-010: Pinned Flutter SDK and Dart Toolchain Baseline
- Date: 2026-10-28
- Change: Recorded Flutter SDK `3.44.6` (channel stable, revision `ee80f08bbf`) and Dart SDK `3.12.2` in documentation and `pubspec.yaml` environment constraints (`sdk: 3.12.2`).
- Why: Prevents toolchain discrepancies between developer environments and CI/build machines.
- Alternatives considered: Floating SDK constraints (`sdk: ^3.0.0`). Rejected to enforce build reproducibility.
- Impact: Explicit environment requirements recorded for all developers.
- Future impact: Toolchain upgrades must be explicitly tested and logged as a new decision record.
- Status: Accepted

## D-011: Format Parameter Passing via Route Query Parameters
- Date: 2026-10-28
- Change: Decided that tool formats will be passed as query parameters (e.g. `/tool/image_convert/flow?format=jpg`) rather than path segments (e.g. `/tool/image_convert/jpg/flow`).
- Why: Separates the resource/tool route identity from the variable configuration state. Format is optional or configurable within the flow.
- Alternatives considered: Path segments (`/tool/:toolId/:format`). Rejected because some tools have a single default format or select formats within the flow.
- Impact: Cleaner route definitions and simplified parsing in `tool_flow_screen.dart`.
- Future impact: Additional tool parameters (e.g., quality, orientation) can be added as query parameters without altering route definitions.
- Status: Accepted

## D-012: Web Platform Target for Local Browser Preview in Brave
- Date: 2026-10-28
- Change: Added `web/` platform scaffolding and configured `CHROME_EXECUTABLE` pointing to Brave Browser (`C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe`).
- Why: Enables immediate local interactive visual preview and debugging on the developer's workstation without requiring an Android emulator or hardware device.
- Alternatives considered: Running headless tests only or installing an Android emulator. Rejected because interactive visual review was requested by the developer.
- Impact: Fast browser-based development workflow with hot reload.
- Future impact: Zero impact on Android/iOS build targets; all Flutter code remains completely cross-platform.
- Status: Accepted

## D-013: Native Splash Screen via Build-Time Dev Dependency
- Date: 2026-10-28
- Change: Added `flutter_native_splash: 2.4.8` to `dev_dependencies` in `pubspec.yaml`, created `flutter_native_splash.yaml` with monochrome light (`#FFFFFF` background, black logo) and dark (`#000000` background, white logo) configurations, generated native Android and iOS splash drawables and storyboards, and placed processed assets in `assets/splash/`.
- Why: Native splash screens require platform-specific XML drawables, Android 12+ splash APIs, and iOS launch storyboards that Dart application code cannot produce. Using a dev-dependency ensures zero runtime packages or overhead are added to the final production application.
- Alternatives considered: Hand-writing native Android XML drawables and iOS LaunchScreen.storyboard manually. Rejected as significantly slower and more prone to cross-device density scaling errors for a solo developer.
- Impact: Clean native splash screen appears instantaneously on OS app launch before Flutter initializes. Retains natural splash duration (until the first frame renders) with zero artificial delays.
- Future impact: Modifying the logo or background colors requires updating `flutter_native_splash.yaml` and re-running `dart run flutter_native_splash:create`. Documented in `README.md`.
- Status: Accepted

## D-014: Splash Screen Hold Duration for Visual Verification & Animation Preparation
- Date: 2026-10-28
- Status: Superseded by D-017
- Change: Added a 2-second initialization delay in `lib/main.dart` before `runApp()` and integrated a DOM `MutationObserver` with fade-out in `web/index.html` to remove the HTML splash screen once `<flutter-view>` is mounted.
- Why: On fast developer workstations with local caching, Flutter engine boots in milliseconds, which causes the native/HTML splash screen to disappear before it can be visually verified. Holding for 2 seconds ensures the branding is clearly visible and establishes the timing window for upcoming custom splash animations.
- Alternatives considered: Instant transition with zero delay. Rejected per developer request to observe and animate the splash screen.
- Impact: Superseded by D-017 which replaced the static delay with an active branded Flutter animation sequence.

## D-015: Persistent Multi-Branch Navigation via StatefulShellRoute.indexedStack
- Date: 2026-10-29
- Change: Refactored navigation in `lib/app.dart` from top-level routes to `StatefulShellRoute.indexedStack` managing three stateful branches: Home (with nested tool flows), Scan, and Settings.
- Why: Top-level routes caused the bottom navigation bar to unmount when pushing tool flows or opening Settings. `StatefulShellRoute.indexedStack` keeps the bottom navigation bar mounted across all screens, preserves navigation state across tabs, keeps the Home icon highlighted while browsing tool flows, and allows tapping "Home" with `initialLocation: true` to return directly to the root tool grid without requiring a hardware back button.
- Alternatives considered: Separate top-level routes with duplicated bottom bars or basic `ShellRoute`. Rejected because basic `ShellRoute` destroys branch state and cannot push sub-routes within an isolated branch stack.
- Zero New Files: All changes are contained within existing `lib/app.dart` and `docs/DECISIONS.md`. No new files or folders are created.
- Status: Accepted

## D-016: Scan-to-PDF Pipeline and Shared Multi-Page Editing Toolbar
- Date: 2026-10-29
- Change: Introduced camera document scanning via `cunning_document_scanner: 3.0.4`, on-device image adjustments (rotation, grayscale, B&W) via `image: 4.10.0`, manual cropping via `image_cropper: 12.2.1`, pure-Dart PDF compilation via `pdf: 3.13.1`, and local sandbox caching via `path_provider: 2.1.6`. Created a shared `DocumentEditorScreen` and `DocumentEditorNotifier` reused identically across the Scan flow and the Image-to-PDF tool flow.
- Why:
  1. Complete on-device Confidential Mode scanning: Provides fast, native multi-page document scanning with auto edge detection and perspective correction without sending any user data off-device.
  2. Single Shared Component: Both camera scans and gallery image conversions require identical multi-page editing operations (crop, rotate, filter, reorder, delete, rename) and PDF generation. Consolidating into one shared `DocumentEditorScreen` eliminates code duplication, guarantees identical behavior, and enforces the "Discard scan?" back-button confirmation uniformly across both flows.
  3. Scope Control: Excluded bloated Adobe Scan features (Magic Eraser, Cleanup clone stamp, Markup drawing, AI mode toggles, cloud OCR) to keep the app focused, lightweight, and strictly on-device.
- Network Safety & Platform Details:
  - Android: Google Play Services ML Kit Document Scanner executes inference strictly on-device. If the ML Kit Document Scanner native module is not already present on the device, Google Play Services may trigger a one-time dynamic component download on first invocation. Subsequent scans and all image processing execute completely offline. Document images, scanned pages, and user metadata are never transmitted over the network.
  - Non-GMS Android Fallback: On Android devices without Google Play Services (e.g. de-googled ROMs, Huawei devices), the scanner initialization fails gracefully via `PlatformException` and displays a clear message directing the user to import pictures via the "Image to PDF" tool.
  - iOS: Uses Apple's VisionKit (`VNDocumentCameraViewController`), which is built directly into iOS 13+ system binaries. Requires zero network downloads, zero dynamic modules, and makes zero network calls.
- Status: Accepted

## D-017: Native Flutter Branded Launch Animation and Cold-Start Gate
- Date: 2026-11-04
- Change: Replaced D-014's artificial 2-second `Future.delayed` in `lib/main.dart` with a native Flutter launch animation sequence (`lib/features/launch/`) hosted inside a `LaunchGate` in `lib/app.dart`.
- Why:
  1. Branded storytelling on cold starts: Paper drops in from top, morphs/folds into a PDF icon, the KrocPDF crocodile mark enters from the left and lunges/eats the PDF document, settling in the center while the "KrocPDF - Fast. Private. On-device." wordmark reveals and holds cleanly for 0.6s before cross-fading to Home. Total duration is 4.2s.
  2. In-memory cold-start flag: Tracks `LaunchGate.hasCompletedLaunch` in memory so the animation plays exclusively on true cold start (process creation), and is completely bypassed on warm resumes, app switching, and in-app navigation. An in-memory flag guarantees that fresh installs and reinstalls always play the animation.
  3. Router decoupling: Hosted in `MaterialApp.router`'s `builder` property via `LaunchGate`, keeping GoRouter state, `StatefulShellRoute` branches, bottom navigation, and deep links completely intact.
  4. Robust accessibility and safety nets:
     - Respects `MediaQuery.disableAnimationsOf(context)` exclusively: bypasses motion and displays a brief static logo/wordmark before transitioning to Home.
     - 6000 ms watchdog timer guarantees fallback to Home if the animation is interrupted.
     - Asset decoding errors trigger immediate graceful fallback to Home without blocking app startup.
     - Tap anywhere immediately skips the sequence.
- Status: Accepted
