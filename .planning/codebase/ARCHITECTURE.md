# System Architecture & Patterns

## High-Level Architecture
KrocPDF follows a feature-first, privacy-by-design architectural pattern:
- **Confidential Mode (Default):** All document and image processing occurs 100% on-device without remote calls.
- **Non-Confidential Mode (Planned):** Cloud-assisted offload for heavy processing formats (e.g. MS Office conversions).

```
lib/
├── app.dart                   # MaterialApp.router configuration, route definitions, theme bindings
├── main.dart                  # ProviderScope entrypoint
├── core/                      # Cross-cutting foundational modules
│   ├── constants/             # Central limits (AppLimits.maxLocalFileBytes = 100MB)
│   ├── errors/                # Domain-level error hierarchy (AppError sealed hierarchy)
│   ├── result/                # Functional Result<T, E> monad
│   ├── theme/                 # Strict monochrome theme design tokens (Light/Dark)
│   └── utils/                 # Utility helpers (e.g. StoragePermissionHelper)
├── features/                  # Independent functional verticals
│   ├── files/                 # Saved/converted PDF storage, listing, viewer, and actions
│   ├── home/                  # Tool grid (8 tools), mode selector, navigation triggers
│   ├── settings/              # Settings screen, limits, privacy policy
│   └── tool_flow/             # 4-stage tool pipeline (Select -> Options -> Progress -> Result)
└── services/                  # Business logic and external capability contracts
    ├── file_validation_service.dart
    ├── image_conversion_service.dart
    └── processing/            # ProcessingService abstraction & implementations
```

## Key Architectural Patterns
1. **Riverpod State Management:** Providers decouple state from widget lifecycles. State management avoids tight widget coupling.
2. **Declarative Routing via `go_router`:** StatefulShellRoute provides persistent bottom navigation between Home and Files while child routes handle tools and flows.
3. **Pluggable Processing Engines:** The `ProcessingService` abstract contract decouples execution from presentation logic.
4. **Strict Error Isolation:** Sealed `AppError` instances encapsulate processing, file-size, and permission errors exhaustively.
