# Technology Stack & Environment

## Languages & SDKs
- **Dart:** 3.12.2 (as configured in `pubspec.yaml`)
- **Flutter:** 3.44.6 (channel stable, pinned per `README.md` and `docs/ARCHITECTURE.md`)
- **Kotlin / Android Gradle Plugin:** Android Gradle Plugin with Kotlin DSL (`build.gradle.kts`)
- **Swift:** iOS runner implementation (`ios/Runner/AppDelegate.swift`)

## Core Dependencies
- **State Management:** `flutter_riverpod: 2.6.1`
- **Routing:** `go_router: 14.8.1` (declarative routing with stateful shell routes)
- **Scanning & Camera:** `cunning_document_scanner: 3.0.4` (ML Kit document scanner integration)
- **Image Manipulation & Cropping:** `image: 4.10.0`, `image_cropper: 12.2.1`, `image_picker: ^1.2.4`, `flutter_image_compress: ^2.5.1`
- **PDF Generation & Manipulation:** `pdf: 3.13.1`, `syncfusion_flutter_pdf: ^35.1.42`, `pdfrx: ^2.4.8`, `printing: ^5.15.1`
- **File System & Sharing:** `path_provider: 2.1.6`, `file_picker: ^13.3.1`, `share_plus: ^13.3.1`
- **Device & System Permissions:** `permission_handler: 11.3.1`, `device_info_plus: ^13.3.0`

## Development & Tooling
- **Linter:** `flutter_lints: 6.0.0`
- **Splash Screen Generator:** `flutter_native_splash: 2.4.8`
- **Testing:** `flutter_test` (unit and widget tests in `test/`)

## Platform Support
- **Android:** Verified (`minSdkVersion = 24`, `targetSdkVersion = 35`).
- **iOS:** Configured (Deployment target `13.0`, bundle identifier `com.krocpdf.app`).
- **Web:** Configured with local browser preview support in Brave / Chrome (`web/index.html`).
