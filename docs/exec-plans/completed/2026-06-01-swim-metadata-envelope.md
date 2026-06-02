# Swim Metadata Envelope Update

## Goal

Update Verve swim metadata export from `properties.metadata.swimming` to the canonical metadata envelope:

```json
{
  "target": "SwimmingMetaData",
  "version": "1.0",
  "data": {}
}
```

## Context

- The exporter currently writes swim metadata under `properties.metadata.swimming`.
- The backend now expects a canonical metadata envelope at `properties.metadata`.
- Existing swim field names inside the payload remain source-neutral camelCase.

## Constraints

- Do not change lap/set field names.
- Do not emit `schemaVersion`; envelope `version` replaces it.
- Keep non-swim exports without metadata.
- Do not add backend code in this repository.

## Files likely to change

- `VerveExporter/GeoJSON.swift`
- `VerveExporter/HealthManager.swift`
- `docs/product-specs/verve-geojson-format.md`
- `docs/design-docs/2026-05-28-swim-metadata-verve-file-extension.md`
- `docs/references/healthkit.md`
- `docs/exec-plans/README.md`

## Validation commands

```bash
make validate-docs
git diff --check
xcodebuild -project VerveExporter.xcodeproj -scheme VerveExporter -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/VerveExporter-DerivedData CODE_SIGNING_ALLOWED=NO OTHER_SWIFT_FLAGS='-disable-sandbox' build
git status --short
```

## Progress log

- 2026-06-01: Created plan for canonical swim metadata envelope update.
- 2026-06-01: Updated Swift encoder models and exporter wiring to emit `properties.metadata.target`, `properties.metadata.version`, and `properties.metadata.data`.
- 2026-06-01: Removed swim payload `schemaVersion`; envelope `version` now carries metadata version.
- 2026-06-01: Updated Verve GeoJSON, swim design, and HealthKit docs for the canonical envelope.
- 2026-06-01: Validation passed: `make validate-docs`, `git diff --check`, and generic iOS build with `OTHER_SWIFT_FLAGS='-disable-sandbox'`.

## Completion criteria

- Swim exports write `properties.metadata.target == "SwimmingMetaData"`.
- Swim exports write `properties.metadata.version == "1.0"`.
- Existing swim fields are nested under `properties.metadata.data`.
- `schemaVersion` is not emitted.
- Non-swim exports continue to omit `properties.metadata`.
- Docs describe the canonical envelope.
