# Architecture

## Project Type And Stack

Project type: native iOS companion app.

Primary stack: Swift, SwiftUI, HealthKit, CoreLocation, Xcode project files.

HarnessHub detected runtimes: none. HarnessHub v0.1 only auto-detects Python and Bun/Vue TypeScript overlays, so Swift/iOS guidance is captured in repository-specific docs instead.

## Repository Layout

- `VerveExporter.xcodeproj/`: Xcode project and scheme metadata.
- `VerveExporter/VerveExporterApp.swift`: SwiftUI app entry point.
- `VerveExporter/ContentView.swift`: Activity browser UI, filter control, month sections, export button, share sheet, and workout display helpers.
- `VerveExporter/WorkoutBrowserModel.swift`: Bounded workout loading, Verve type filtering, incremental reveal, and browser loading state.
- `VerveExporter/DebugView.swift`: JSON preview sheet that reuses the export path and shows generated output for inspection.
- `VerveExporter/HealthManager.swift`: HealthKit authorization, workout queries, route and heart-rate queries, GeoJSON assembly, and export file generation.
- `VerveExporter/HealthManager+Swimming.swift`: Swimming lap, set, and workout metadata construction.
- `VerveExporter/HealthManager+SwimDiagnostics.swift`: Diagnostic JSON for swimming workouts and HealthKit metadata.
- `VerveExporter/WorkoutFeatureBuilder.swift`: Route and heart-rate feature construction for GeoJSON.
- `VerveExporter/ActivityMapping.swift`: Verve activity categories and workout row icon mappings.
- `VerveExporter/GeoJSON.swift`: Encodable Swift models for the Verve GeoJSON export structure.
- `VerveExporterTests/`: In-memory synthetic workout tests for the export builder.
- `VerveExporter/VerveExporter.entitlements`: HealthKit entitlement.
- `docs/`: Harness, product, testing, security, and reference docs for future agents.

## Known Layers Or Modules

- UI layer: SwiftUI views in `ContentView.swift` and `DebugView.swift`, with browsing state in `WorkoutBrowserModel.swift`.
- HealthKit access layer: `HealthManager`, `HKHealthStore`, workout queries, route queries, and heart-rate sample queries.
- Export construction layer: `WorkoutFeatureBuilder`, swimming metadata construction, and activity mappings feed the `GeoJSON.swift` models.
- Export model layer: `GeoJSON.swift` structures, aligned with the Verve backend Pydantic schema in `/Users/korbinian/Code/verve/backend/verve_backend/schema/verve_file.py`.
- File output layer: temporary JSON files generated for ShareLink export.

## Dependency Direction

SwiftUI views depend on `WorkoutBrowserModel`, `HealthManager`, and the workout icon mapping. The browser model uses bounded HealthKit workout queries and the shared Verve activity mapper. `HealthManager` and its same-type extensions depend on HealthKit/CoreLocation, activity mappings, feature construction, and the export model structs. `GeoJSON.swift` should stay independent of HealthKit so encoding can be tested without HealthKit data.

## Boundaries Agents Must Respect

- Treat the Verve GeoJSON format as a shared interface with the Verve frontend/backend. Read `docs/product-specs/verve-geojson-format.md` before changing field names, units, nullability, or activity type mappings.
- Treat HealthKit authorization and query behavior as privacy-sensitive. Read `docs/references/healthkit.md` before changing permissions or sample types.
- Do not add backend upload behavior, network calls, account state, or Verve API integration without a product spec.
- Do not commit real HealthKit exports or personal workout route files.
- Keep generated export files out of git unless a file is explicitly sanitized and documented as a fixture.

## Validation Boundaries

Document where external input is validated before it enters core logic.

- Configuration: Xcode build settings define bundle id, HealthKit entitlement, generated Info.plist, and `NSHealthShareUsageDescription`.
- Files and paths: export files are written to `FileManager.default.temporaryDirectory`; no imported file parsing exists in the app today.
- Command output: build and inspection commands are documented in `docs/TESTING.md`; simulator errors may be environmental.
- API or service input: HealthKit access is mediated by `HKHealthStore.requestAuthorization`, sample predicates, and route queries.
- Dataframes, datasets, or model inputs: not applicable.

## Current Unknowns

- Synthetic in-memory HealthKit workout, route, and heart-rate inputs cover repeatable export tests; saved HealthKit query integration is not yet automated.
- The exact safe CI-grade `xcodebuild` destination is not confirmed.
- HealthKit coverage for cadence, cycling power, speed, and elevation gain is not yet documented beyond current route and heart-rate export behavior.
