# Documentation Map

Repository-local documentation is the system of record for future agents. If durable knowledge matters, put it in this repository instead of relying on chat history.

## Core Documents

- `../AGENTS.md`: Short agent entry point and table of contents.
- `../ARCHITECTURE.md`: Repository layout, offline geoid interpolation/loading and HealthKit conversion, focused conformance tests, unified contract boundary, and dependency direction.
- `PRINCIPLES.md`: Harness operating principles.
- `TESTING.md`: Bulk selection/cancellation/multi-file smoke checks and safe validation commands, all-source lint for untracked Swift files, plain-location elevation regressions, public geoid vectors, route/swimming diagnostics, and device/offline smoke checks.
- `SECURITY.md`: Attempt-owned bulk temporary files, secrets, HealthKit data, synthetic fixture rules, the public EGM2008 resource exception, and forbidden handling patterns.
- `QUALITY_SCORE.md`: Sixty-four passing tests, the corrected elevation-validation gap, historical coverage, and remaining device/latency checks.
- `../.gitattributes`: Preserves the immutable geoid resource as binary bytes without text conversions.
- `DECISIONS.md`: Separate-file bulk export and compact decision log, including corrected offline EGM2008 height provenance, conservative swimming derivations, palette choices, timezone, and synthetic tests.

## Work Areas

- `product-specs/`: Product behavior, file formats, business rules, user-visible requirements, and acceptance criteria.
- `design-docs/`: Technical rationale, architecture choices, trade-offs, and larger change designs.
- `exec-plans/`: Active and completed execution plans, including export tests, plus the technical debt tracker.
- `references/`: Domain and API reference notes, including HealthKit findings.

## Key Project References

- `product-specs/bulk-export.md`: Bulk selection, progress, failures, cancellation and temporary-file ownership.

- `exporter-release-changes.md`: Verve GeoJSON 1.0 handoff, acceptance requirements, and completed implementation/validation record.
- `QUALITY_SCORE.md`: Current synthetic test evidence and historical coverage measurement, with remaining device/UI integration gaps.

- `product-specs/activity-browser.md`: Recent workout browsing, Verve type filtering, month grouping, and incremental reveal.
- `product-specs/verve-geojson-format.md`: Verve GeoJSON export contract, omitted moving duration, recorded IANA timezone, timestamp rules, and empty-workout behavior.
- `product-specs/verve-swimming-metadata.md`: Shareable Verve swimming metadata contract.
- `references/healthkit.md`: HealthKit documentation links, bounded workout queries, synthetic test guidance, recorded timezone metadata semantics, and moving-duration research backlog.
- `../VerveExporter/Resources/Geoid/README.md`: Public EGM2008 resource source, checksum, redistribution notes, conversion limits, and independent reference-vector provenance.
