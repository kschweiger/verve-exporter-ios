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

## Forbidden Handling Patterns

- Do not print secrets or tokens in logs.
- Do not paste secrets, real routes, or full real workout JSON into docs, issues, merge requests, or agent responses.
- Do not commit local datasets, generated artifacts, personal workouts, route exports, or credentials unless explicitly documented as safe.
- Do not run destructive, production, migration, training, Health data deletion, or shared-environment commands without explicit approval.
- Do not add network upload/sync behavior without documenting authentication, privacy, and failure handling first.

## Unknowns To Confirm

- Whether any sanitized fixture exports may be checked in later.
- Whether the app will ever upload directly to the Verve backend or remain a local share/export tool.
- Whether additional HealthKit permissions will be needed for cadence, power, speed, elevation, or other metrics.
