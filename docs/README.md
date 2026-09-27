# Documentation Map

Repository-local documentation is the system of record for future agents. If durable knowledge matters, put it in this repository instead of relying on chat history.

## Core Documents

- `../AGENTS.md`: Short agent entry point and table of contents.
- `../ARCHITECTURE.md`: Repository layout, stack, boundaries, dependency direction, and validation boundaries.
- `PRINCIPLES.md`: Harness operating principles.
- `TESTING.md`: Safe validation commands, unknown commands, and unsafe or expensive checks.
- `SECURITY.md`: Secrets, HealthKit data, local-only files, data constraints, and forbidden handling patterns.
- `QUALITY_SCORE.md`: Lightweight quality score, gaps, and next actions.
- `DECISIONS.md`: Compact decision log, including export time zone selection, with links to design docs when more rationale is needed.

## Work Areas

- `product-specs/`: Product behavior, file formats, business rules, user-visible requirements, and acceptance criteria.
- `design-docs/`: Technical rationale, architecture choices, trade-offs, and larger change designs.
- `exec-plans/`: Active and completed execution plans plus the technical debt tracker.
- `references/`: Domain and API reference notes, including HealthKit findings.

## Key Project References

- `product-specs/verve-geojson-format.md`: Verve GeoJSON export contract and timestamp time zone rules for this app.
- `product-specs/verve-swimming-metadata.md`: Shareable Verve swimming metadata contract.
- `references/healthkit.md`: HealthKit documentation links, current usage and time zone notes, and research backlog.
