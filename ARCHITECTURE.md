# Architecture

## Project Type And Stack

Project type: native iOS companion app.

Primary stack: Swift, SwiftUI, HealthKit, CoreLocation, Xcode project files.

HarnessHub detected runtimes: none. HarnessHub v0.1 only auto-detects Python and Bun/Vue TypeScript overlays, so Swift/iOS guidance is captured in repository-specific docs instead.

## Repository Layout

- `VerveExporter.xcodeproj/`: Xcode project and scheme metadata.
- `VerveExporter/VerveExporterApp.swift`: SwiftUI app entry point.
- `VerveExporter/ContentView.swift`: Activity browser, filtering, month sections, and bulk selection controls.
- `VerveExporter/WorkoutRow.swift`: Workout display, individual export preparation, and the shared native share controller wrapper.
- `VerveExporter/BulkExportModel.swift` and `BulkExportSheet.swift`: Sequential batch preparation, selection mode, partial failures, cancellation, and share presentation. Share success directly resets selection mode and closes presentation; pending completion identity survives file cleanup but is invalidated by a new selection action or batch.
- `VerveExporter/ExportFileWriter.swift`: Collision-safe atomic JSON writing into an attempt-owned directory.
- `VerveExporter/WorkoutBrowserModel.swift`: Bounded workout loading, Verve type filtering, incremental reveal, and browser loading state.
- `VerveExporter/DebugView.swift`: JSON preview sheet that reuses the export path and shows generated output for inspection.
- `VerveExporter/HealthManager.swift`: HealthKit authorization, workout queries, route and heart-rate queries, GeoJSON assembly, and export file generation.
- `VerveExporter/HealthManager+Swimming.swift`: Swimming lap, set, and workout metadata construction.
- `VerveExporter/HealthManager+SwimDiagnostics.swift`: Diagnostic JSON for swimming workouts and HealthKit metadata.
- `VerveExporter/WorkoutFeatureBuilder.swift`: Route and heart-rate feature construction for GeoJSON.
- `VerveExporter/HealthManager+Elevation.swift`: Validates HealthKit sea-level source heights and converts them to explicit ellipsoidal height arrays.
- `VerveExporter/GeoidGrid.swift` and `BundledGeoidGrid.swift`: Foundation-only global PGM interpolation plus lazy, checksum-validated loading of the public EGM2008 resource.
- `VerveExporter/Resources/Geoid/`: Immutable EGM2008 grid and its source/checksum/redistribution notes.
- `VerveExporter/ActivityMapping.swift`: Verve activity categories and workout row icon mappings.
- `VerveExporter/GeoJSON.swift`: Encodable Swift models for the Verve GeoJSON export structure.
- `VerveExporterTests/`: In-memory synthetic export, route/swimming conformance, and diagnostic tests; focused test extensions reuse invented fixture helpers.
- `VerveExporter/VerveExporter.entitlements`: HealthKit entitlement.
- `docs/`: Harness, product, testing, security, and reference docs for future agents.

## Known Layers Or Modules

- UI layer: SwiftUI views in `ContentView.swift` and `DebugView.swift`, with browsing state in `WorkoutBrowserModel.swift`.
- HealthKit access layer: `HealthManager`, `HKHealthStore`, workout queries, route queries, and heart-rate sample queries.
- Export construction layer: HealthKit elevation conversion, `WorkoutFeatureBuilder`, swimming metadata construction, and activity mappings feed the `GeoJSON.swift` models. The feature builder consumes already converted height arrays and applies no datum conversion.
- Export model layer: `GeoJSON.swift` structures, aligned with the unified core/swimming 1.0 contracts documented in `docs/product-specs/`. The backend Pydantic consumer is in `/Users/korbinian/Code/verve/backend/verve_backend/schema/verve_file.py`.
- File output layer: temporary JSON files shared with UIActivityViewController. Bulk attempts own isolated directories, retain URLs through sharing, and remove their directories after dismissal or after cancelled in-flight work finishes.

## Dependency Direction

SwiftUI views depend on `WorkoutBrowserModel`, `HealthManager`, and the workout icon mapping. The browser model uses bounded HealthKit workout queries and the shared Verve activity mapper. `HealthManager` and its same-type extensions depend on HealthKit/CoreLocation, activity mappings, feature construction, and the export model structs. `GeoidGrid` depends only on Foundation; its bundle loader additionally uses the native CryptoKit framework for SHA-256. The immutable grid is cached lazily for spatial exports, with no geoid loading for heart-rate-only exports. `GeoJSON.swift` stays independent of HealthKit.

## Boundaries Agents Must Respect

- Treat the Verve GeoJSON format as a shared interface with the Verve frontend/backend. Read `docs/product-specs/verve-geojson-format.md` before changing field names, units, nullability, or activity type mappings.
- Treat HealthKit authorization and query behavior as privacy-sensitive. Read `docs/references/healthkit.md` before changing permissions or sample types.
- Do not add backend upload behavior, network calls, account state, or Verve API integration without a product spec.
- Do not commit real HealthKit exports or personal workout route files.
- Keep generated export files out of git unless a file is explicitly sanitized and documented as a fixture.

## Validation Boundaries

Document where external input is validated before it enters core logic.

- Configuration: Xcode build settings define bundle id, HealthKit entitlement, generated Info.plist, and `NSHealthShareUsageDescription`.
- Files and paths: export files are written to `FileManager.default.temporaryDirectory`; no imported workout-file parsing exists. The bundled public geoid file is checked against a pinned byte count and SHA-256 before parsing its dimensions, metadata, and raster boundaries. Missing/damaged data fails export explicitly.
- Command output: build and inspection commands are documented in `docs/TESTING.md`; simulator errors may be environmental.
- API or service input: HealthKit access is mediated by `HKHealthStore.requestAuthorization`, sample predicates, and route queries.
- Model inputs: the bundled global EGM2008 geoid supports an approximate mean-sea-level to WGS 84 ellipsoidal-height conversion. Its source and uncertainty limits are documented with the resource. Invalid coordinates/horizontal accuracy, nonfinite altitude, nonpositive/nonfinite vertical accuracy, or nonfinite derived heights are rejected before file writing.

## Current Unknowns

- Synthetic in-memory HealthKit workout, route, and heart-rate inputs cover repeatable export tests; saved HealthKit query integration is not yet automated.
- The exact safe CI-grade `xcodebuild` destination is not confirmed.
- HealthKit coverage for cadence, cycling power, speed, and elevation gain is not yet documented beyond current route and heart-rate export behavior.
