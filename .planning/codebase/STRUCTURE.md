# Codebase Directory Structure

```
.
├── .github/                   # (Planned) Workflows for CI/CD and repository checks
├── .planning/                 # Project governance, plans, and codebase intelligence
│   └── codebase/              # Codebase maps and technical specifications
├── android/                   # Native Android host project (Kotlin DSL gradle files)
│   ├── app/
│   │   ├── build.gradle.kts   # Android application build configuration
│   │   └── src/               # Manifests, Kotlin source, and native resources
│   └── gradle/                # Gradle wrapper scripts and distribution
├── assets/                    # Static runtime assets
│   └── splash/                # Monochrome splash logos (light & dark)
├── docs/                      # Human-readable architectural records
│   ├── ARCHITECTURE.md        # Technical architecture specification
│   └── DECISIONS.md           # Architecture Decision Records (ADRs D-001 through D-016)
├── ios/                       # Native iOS host project (Xcode workspace, Runner, Swift)
├── lib/                       # Flutter / Dart application source code
│   ├── app.dart               # App widget & GoRouter route tree configuration
│   ├── main.dart              # Global entrypoint with ProviderScope
│   ├── core/                  # Core design tokens, theme, errors, constants
│   ├── features/              # Feature modules (files, home, settings, tool_flow)
│   └── services/              # File, image, and processing services
├── test/                      # Unit and widget test suite
│   ├── files_screen_test.dart
│   ├── widget_test.dart
│   └── unit/                  # Specialized unit tests (limits, image conversion, etc.)
├── web/                       # Web platform host resources for browser preview
├── analysis_options.yaml      # Static analysis and lint configurations
├── flutter_native_splash.yaml # Splash screen configuration
└── pubspec.yaml               # Pinned package dependencies and project metadata
```

