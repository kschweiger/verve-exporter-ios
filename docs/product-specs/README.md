# Product Specs

Product specs describe what the product or project should do.

Use this directory for:

- User-visible behavior.
- File format contracts.
- Business rules.
- Feature requirements.
- Acceptance criteria.
- Non-goals and constraints that affect product behavior.

Create a product spec before implementing new user-visible behavior when requirements are not already clear in repository-local docs.

## Current Specs

- `bulk-export.md`: Select loaded workouts, prepare sequentially, and share multiple JSON files with partial-failure handling.

- `activity-browser.md`: Recent workout browsing, Verve type filtering, month grouping, incremental reveal, and distinct palette colors for activity and export icons.
- `verve-geojson-format.md`: Unified core 1.0 contract and iOS offline EGM2008 elevation estimates, geometry/sample requirements, optional statistics, fixed units, and capability limits.
- `verve-swimming-metadata.md`: Unified swimming 1.0 contract: counts, indices, elapsed timing, precision-aware SWOLF derivation, overflow-safe stroke totals, and complete synthetic examples.
