# Coding Conventions & Design System

## Design System & Theme Conventions
- **Strict Monochrome Theme:** Light theme uses `#FFFFFF` background with `#E5E5E5` 1px borders; Dark theme uses `#000000` background with `#2A2A2A` 1px borders.
- **Zero Color Accents:** No colored FABs, buttons, or highlights; utilitarian, high-contrast, minimalist look.
- **Flat Surfaces:** Zero drop shadows or elevations across cards, app bars, and dialogs.
- **Uniform Spacing:** 8-point spatial grid system (4, 8, 16, 24, 32).
- **Corner Radii:** Consistent 6px border radii across tiles, dialogs, and interactive elements.

## Code Standards
- **Linting:** Rules enforced via `flutter_lints: 6.0.0` defined in `analysis_options.yaml`.
- **Error Handling:** Sealed classes for errors (`AppError`), returning functional `Result<T, E>` instances rather than throwing uncaught exceptions.
- **Limits & Guardrails:** Never hardcode size or threshold values; reference `AppLimits` (`AppLimits.maxLocalFileBytes`).
- **Feature Independence:** Vertical feature folders (`features/<name>/{presentation, domain, data}`) keep features self-contained.
- **Dependency Injections:** Riverpod providers defined near domain/presentation boundaries.
