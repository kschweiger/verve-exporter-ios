# Decisions

This is the compact decision log. Keep entries short. If a decision needs longer rationale, create or update a design document in `docs/design-docs/` and link it from the entry.

## Entries

### 2026-05-28: Initialize repository agent harness

Decision: Initialize this repository with HarnessHub v0.1 from local source `/Users/korbinian/harnesshub`.

Context: The repository needs local agent-readable guidance, documentation structure, safety rules, Verve format knowledge, and HealthKit reference notes.

Design reference: `docs/design-docs/README.md`

Consequences: Future agents should use `AGENTS.md`, `ARCHITECTURE.md`, and `docs/` as the system of record.

Follow-up checks: Confirm automated test strategy, real-device smoke-test flow, and fixture policy.

### 2026-05-28: Treat Verve GeoJSON as a shared interface

Decision: Document the current Verve GeoJSON contract in `docs/product-specs/verve-geojson-format.md` and require agents to consult it before changing export fields.

Context: The iOS app exports data consumed by the Verve frontend/backend, whose current local references are `/Users/korbinian/Code/verve/frontend/src/views/HelpView.vue` and `/Users/korbinian/Code/verve/backend/verve_backend/schema/verve_file.py`.

Consequences: Field names, units, nullability, and activity mappings are compatibility-sensitive.

Follow-up checks: Add automated tests that encode sample Verve JSON and validate key names.

### 2026-05-28: Add Makefile validation entry points

Decision: Add `Makefile` targets for harness validation, Xcode scheme inspection, signing-disabled generic iOS builds, and the full validation path.

Context: Future agents need stable commands that match the repository docs instead of reconstructing long `xcodebuild` invocations.

Consequences: Prefer `make validate-docs`, `make validate-build`, and `make validate` in agent workflows. Keep `docs/TESTING.md` synchronized when targets change.
