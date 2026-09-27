# Pre-commit Lint Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `uvx pre-commit run -a` pass while preserving export and UI behavior.

**Architecture:** Keep the existing HealthKit responsibilities, but move swimming metadata construction, swimming diagnostics, and activity categorization into focused helper types so the exporter remains easy to scan and meets SwiftLint's size and complexity limits. Add a SwiftFormat setting that agrees with SwiftLint's no-trailing-comma rule.

**Tech Stack:** Swift, SwiftUI, HealthKit, SwiftFormat, SwiftLint, pre-commit.

**Spec:** `.pre-commit-config.yaml`, `docs/TESTING.md`, and `docs/product-specs/verve-geojson-format.md`.

## Global Constraints

- Preserve HealthKit permissions, query behavior, workout mappings, exported fields, and UI text.
- Do not add dependencies or change Xcode signing/project settings.
- Do not add or run XCTest; the requested gate is the pre-commit suite.
- Do not suppress SwiftLint rules to make the hooks pass.

## Review Focus

- GPS and nearby heart-rate alignment must retain existing behavior.
- Heart-rate-only exports must retain null geometry.
- Swimming metadata and diagnostic JSON must retain their existing shape and values.
- Activity types must retain their current Verve categories and UI icon names.
- Workout timezone and filename behavior must remain unchanged.

---

### Task 1: Reconcile formatter and linter settings

**Files:**
- Create: `.swiftformat`
- Modify: Swift files reported by SwiftFormat

- [x] Run SwiftFormat over the Swift source and test files.
- [x] Configure SwiftFormat to omit trailing commas and keep multiline statement braces on the declaration line, matching SwiftLint's rules.
- [x] Run the SwiftFormat hook and confirm it passes.

### Task 2: Reduce SwiftLint structural violations

**Files:**
- Modify: `VerveExporter/HealthManager.swift`
- Create: focused helpers under `VerveExporter/`
- Modify: `VerveExporter/ContentView.swift`

- [x] Move swim metadata assembly and swim diagnostic JSON into focused helper types.
- [x] Move workout activity categorization and icon lookup into focused mappings.
- [x] Extract GeoJSON construction steps where needed to meet function limits.
- [x] Keep each Swift file and type within SwiftLint's configured default limits.

### Task 3: Resolve remaining style violations

**Files:**
- Modify: `VerveExporter/ContentView.swift`
- Modify: `VerveExporter/HealthManager.swift`
- Modify: `VerveExporterTests/ExportTests.swift`

- [x] Fix optional initialization, closure syntax, parameter naming, and line lengths without changing behavior.
- [x] Run `uvx pre-commit run -a`; all applicable hooks passed.

### Task 4: Close the plan

**Files:**
- Move: this plan to `docs/exec-plans/completed/`
- Modify: `docs/exec-plans/README.md`

- [x] Record the validation result and move this plan from active to completed.

Validation: `uvx pre-commit run -a` passed. `make validate-docs` passed. `make validate-build` passed after an escalated rerun; the sandboxed attempt was blocked before compilation while writing Xcode caches and DerivedData. XCTest was not run because this task requested the hooks, and the export tests were not part of the requested validation.

Final review: Independent static review found no code issues. The architecture and documentation maps were updated to include the extracted helpers and lint checks.
