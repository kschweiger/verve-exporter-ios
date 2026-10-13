# Security And Data Handling

## No-Secrets Rule

Never commit secrets, credentials, access tokens, private keys, local credential files, customer data, regulated data, or private datasets unless this repository explicitly documents that they are safe to track.

## Local-Only Agent Files

These paths are reserved for local-only agent state and credentials:

```text
.env.agent.local
.agent-local/
```

They must stay untracked.

## Data Constraints

This app reads Apple HealthKit workout data. Workout exports may contain sensitive personal information, including locations, timestamps, activity habits, route patterns, heart rate, calorie estimates, and device-derived metadata.

Treat all real exports and debug previews as private unless the user explicitly marks a specific file as sanitized and safe to commit.

Export unit tests may construct invented `HKWorkout`, `HKQuantitySample`, `HKWorkoutEvent`, and `CLLocation` objects in memory. Keep fixture coordinates, dates, and health values invented. Do not seed a personal device's HealthKit store for automated tests.

## Forbidden Handling Patterns

The canonical GeographicLib `egm2008-5.pgm` global geoid grid is public NGA-derived geophysical data, unrelated to personal workouts. It may be tracked as an immutable application resource alongside its source URL, SHA-256, redistribution notice, and attribution. Public NGA-derived geoid reference vectors and invented miniature test grids are also safe fixtures. Download only public model data during development; the app must never upload route positions or query a geoid service at runtime.

- Do not print secrets or tokens in logs.
- Do not paste secrets, real routes, or full real workout JSON into docs, issues, merge requests, or agent responses.
- Do not commit local datasets, generated artifacts, personal workouts, route exports, or credentials unless explicitly documented as safe.
- Do not run destructive, production, migration, training, Health data deletion, or shared-environment commands without explicit approval.
- Do not add network upload/sync behavior without documenting authentication, privacy, and failure handling first.

## Unknowns To Confirm

- Whether a future saved-HealthKit simulator integration fixture can be checked in; current in-memory fixtures contain invented values only.
- Whether the app will ever upload directly to the Verve backend or remain a local share/export tool.
- Whether additional HealthKit permissions will be needed for cadence, power, speed, elevation, or other metrics.
