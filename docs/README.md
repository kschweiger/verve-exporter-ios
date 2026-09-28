# Documentation Map

Repository-local documentation is the system of record for future agents. If durable knowledge matters, put it in this repository instead of relying on chat history.

## Core Documents

- `../AGENTS.md`: Short agent entry point and table of contents.
- `../ARCHITECTURE.md`: Repository layout, including the activity browser model and focused HealthKit/export helper files, stack, boundaries, dependency direction, and validation boundaries.
- `PRINCIPLES.md`: Harness operating principles.
- `TESTING.md`: Safe validation commands, pre-commit lint/format checks, synthetic export and swim diagnostic XCTest coverage, and real-device browser/export smoke checks.
- `SECURITY.md`: Secrets, HealthKit data, synthetic fixture rules, and forbidden handling patterns.
- `QUALITY_SCORE.md`: Lightweight quality score, measured app coverage, gaps, and next actions.
- `DECISIONS.md`: Compact decision log, including export time zone, moving-duration omission, and synthetic test choices.

## Work Areas

- `product-specs/`: Product behavior, file formats, business rules, user-visible requirements, and acceptance criteria.
- `design-docs/`: Technical rationale, architecture choices, trade-offs, and larger change designs.
- `exec-plans/`: Active and completed execution plans, including export tests, plus the technical debt tracker.
- `references/`: Domain and API reference notes, including HealthKit findings.

## Key Project References

- `product-specs/activity-browser.md`: Recent workout browsing, Verve type filtering, month grouping, and incremental reveal.
- `product-specs/verve-geojson-format.md`: Verve GeoJSON export contract, omitted moving duration, timestamp rules, and empty-workout behavior.
- `product-specs/verve-swimming-metadata.md`: Shareable Verve swimming metadata contract.
- `references/healthkit.md`: HealthKit documentation links, bounded workout queries, synthetic test guidance, and moving-duration research backlog.
