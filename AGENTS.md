# Agent Guide

## Project Summary

Verve Exporter is a small SwiftUI iOS companion app for the Verve sports activity web application. It reads workouts, routes, and heart-rate data from Apple HealthKit and exports selected workouts as Verve-compatible GeoJSON.

## Start Here

- Read `ARCHITECTURE.md` before changing code or docs.
- Use `docs/README.md` as the documentation map.
- Check `docs/TESTING.md` before running validation commands.
- Check `docs/SECURITY.md` before handling HealthKit data, exported workouts, local files, or external services.
- Read `docs/product-specs/verve-geojson-format.md` before changing export JSON.
- Read `docs/references/healthkit.md` before changing HealthKit permissions, queries, or workout data extraction.
- Record durable decisions in `docs/DECISIONS.md`; use `docs/design-docs/` for longer technical rationale.
- Use `docs/product-specs/` for user-visible behavior, file format rules, requirements, and acceptance criteria.

## Planning Rule

Small changes may use a lightweight plan in the agent session. Larger changes, HealthKit changes, export format changes, architecture changes, or risky changes must create an execution plan under `docs/exec-plans/active/` before implementation and move it to `docs/exec-plans/completed/` when done.

## Validation Rule

Before claiming work is complete, run the safest relevant validation commands from `docs/TESTING.md`. If commands are missing, unsafe, expensive, or unavailable, record that fact in the final response and update the relevant docs or `docs/exec-plans/tech-debt-tracker.md`.

## Safe Commands

- `uvx pre-commit run -a`
- `make validate-docs`
- `make validate-lint`
- `make xcode-list`
- `make validate-build`
- `make validate`
- `xcodebuild -list -project VerveExporter.xcodeproj`
- `xcodebuild -project VerveExporter.xcodeproj -scheme VerveExporter -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/VerveExporter-DerivedData CODE_SIGNING_ALLOWED=NO build`
- `git status --short`
- `rg <pattern>`

Use `make validate-docs` for fast harness checks. Use `make validate-lint` for SwiftFormat, SwiftLint, and pre-commit checks; it also runs plutil. Use `make validate-build` for the generic iOS compiler check, and `make validate` to run docs, lint, and build validation. HealthKit route and workout behavior still requires a configured real device and real or fixture workout data.

## Unsafe Commands

- Do not run commands that erase DerivedData, reset signing, delete simulator/device data, or modify user Health data without explicit approval.
- Do not export, commit, paste, or upload real workout files unless the user explicitly says the specific file is safe to use.
- Do not run package managers, dependency changes, signing/provisioning changes, or Xcode project rewrites unless the task requires them and the user has approved the scope.

## Security Rule

Never commit secrets, credentials, tokens, private keys, local datasets, personal HealthKit exports, real workout route files, or generated artifacts unless the repository explicitly documents that they are safe to track. Keep local-only agent state in `.agent-local/` and local credentials in `.env.agent.local`.

## Harness Metadata

This repository was bootstrapped with HarnessHub from the local source at `/Users/korbinian/harnesshub`. Treat `.agent-harness/manifest.json` and `.agent-harness/selection.yml` as historical bootstrap records. Update project knowledge in repo-local docs instead of relying on chat history or editing bootstrap metadata casually.

## Housekeeping Rules

- Any new or changed document must update the corresponding index file in the same change set.
- Any change that introduces or alters tooling behavior must update the corresponding config or docs in the same change set.
- Broken, stale, or contradictory docs are defects and must be corrected.
- Future agents must update repository-local harness docs when they discover durable rules, constraints, HealthKit findings, or recurring issues.

## Runtime Guidance

HarnessHub v0.1 has no Swift/iOS runtime overlay. Use the repository-specific guidance in `ARCHITECTURE.md`, `docs/TESTING.md`, and `docs/references/healthkit.md`.
