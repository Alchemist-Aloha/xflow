# XFlow Repository Instructions

## Project Overview
XFlow is a single Flutter application at the repository root. The app entrypoint is [lib/main.dart](lib/main.dart), which initializes Flutter, `media_kit`, the database, and Twitter account state before launching a `ProviderScope`-wrapped `MaterialApp`.

## Repository Map
- [lib/](lib) contains the application code.
- [test/](test) contains widget, feature, core, and database tests.
- [docs/](docs) contains project documentation and the vendored Twitter API documentation subtree.
- [android/](android) contains the Android host project and release workflow inputs.
- [web/](web) contains the web app shell and manifest.
- [build/](build) is generated output and must not be edited by hand.

## Sources of Truth
- Dependency and SDK constraints: [pubspec.yaml](pubspec.yaml)
- Static analysis configuration: [analysis_options.yaml](analysis_options.yaml)
- App entrypoint and shell structure: [lib/main.dart](lib/main.dart)
- Root release workflow: [.github/workflows/release.yml](.github/workflows/release.yml)
- Test suite: [test/](test)
- User-facing project overview: [README.md](README.md)

## Environment And Setup
- Use Flutter from the repository root.
- Required Dart SDK constraint is `>=3.0.0 <4.0.0` from [pubspec.yaml](pubspec.yaml).
- Run `flutter pub get` from the repository root before running or testing the app.
- `flutter doctor` is a useful local environment check when setup is failing.

## Common Commands
- Install dependencies: run `flutter pub get` from the repository root.
- Start the app: run `flutter run` from the repository root.
- Static analysis: run `flutter analyze` from the repository root.
- Tests: run `flutter test` from the repository root.
- Android release build: run `flutter build apk --release --split-per-abi` from the repository root.
- Formatting: use `dart format` on touched Dart files from the repository root.

## Architecture And Boundaries
- `lib/core/` holds app-wide services, persistence, navigation, client logic, and shared utilities.
- `lib/features/` holds feature-specific UI and state for feed, profile, subscriptions, settings, auth, and player flows.
- `main.dart` uses Riverpod state and `PopScope` to manage tab navigation and overlay screens inside a single shell; do not assume a named-route architecture.
- Database and Twitter client code are initialized before `runApp`, so changes that touch startup order should be treated carefully.
- `core` and `features` are conventional layers, not a strict import boundary; preserve the existing directionality of dependencies when possible.

## Coding Conventions
- Follow the analyzer and lint rules from [analysis_options.yaml](analysis_options.yaml).
- Keep changes consistent with the existing Riverpod, `MaterialApp`, and Flutter widget patterns already used in [lib/main.dart](lib/main.dart) and neighboring files.
- Prefer existing repository abstractions over introducing new architecture unless a change clearly requires it.

## Testing And Validation
- Put widget and feature tests under [test/](test), matching the existing `test/<area>/<name>_test.dart` layout.
- Use `sqflite_common_ffi` in database tests that need local SQLite access, as shown in [test/core/database/repository_test.dart](test/core/database/repository_test.dart).
- For routine Dart code changes, prefer `flutter test` plus `flutter analyze`; use a narrower test file when the change is localized.
- For release-related changes, validate with `flutter build apk --release --split-per-abi`.

## Generated, Vendored, Or Protected Files
- Do not edit files under [build/](build) by hand.
- Treat generated test mocks such as `*.mocks.dart` files under [test/](test) as generated artifacts unless a workflow explicitly says otherwise.
- Keep documentation in [docs/TwitterInternalAPIDocument/](docs/TwitterInternalAPIDocument) aligned with its own instructions file if present.

## Change-Specific Guidance
- When changing startup, navigation, persistence, or background-sync behavior, inspect the call chain from [lib/main.dart](lib/main.dart) through the touched feature or core service before editing.
- When changing database behavior, verify the corresponding repository tests under [test/core/database/](test/core/database) or add a focused test there.
- When changing release packaging, keep the root workflow in [.github/workflows/release.yml](.github/workflows/release.yml) aligned with the build command it runs.

## Definition Of Done
- The touched instruction file(s) should describe only verified repository-specific guidance.
- Referenced files and commands should exist and match the repository's actual tooling.
- Validate the change with `git diff --check` and the narrowest useful Dart/Flutter command for the touched instruction files, if any exists.

## Relevant Documentation
- [README.md](README.md)
- [docs/tutorial/tutorial.md](docs/tutorial/tutorial.md)
- [docs/tutorial/testing_ci.md](docs/tutorial/testing_ci.md)
- [docs/TwitterInternalAPIDocument/README.md](docs/TwitterInternalAPIDocument/README.md)