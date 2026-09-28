# Activity Browser Implementation Plan

> **For agentic workers:** Execute the tasks in order and mark each completed step. Use the repository's validation guidance before completion.

**Goal:** Make the latest matching workout easiest to export and make older workouts browsable by month and Verve activity type.

**Architecture:** Keep export behavior in `WorkoutRow` and `HealthManager`. Add bounded workout prefix queries in `HealthManager`, derive visible matches from the shared Verve mapper, and keep browsing state in a focused view model. Build latest, history, filter, and loading states in SwiftUI.

**Tech Stack:** Swift, SwiftUI, HealthKit, Xcode.

**Spec:** `docs/product-specs/activity-browser.md`

## Global Constraints

- Keep HealthKit authorization types, GeoJSON, and share/export behavior unchanged.
- Do not read route or heart-rate samples while browsing.
- Do not use or commit real workout exports.
- Group months using the device's current calendar and time zone.

## Review Focus

- Rare Verve types must search beyond the first ten workouts.
- An empty filter must show a clear action and must not imply HealthKit permission status.
- Changing or clearing a filter while a query is in flight must not display stale results.
- A failed refresh or Show more request must preserve the visible workouts.
- New HealthKit workouts inserted between queries must not create duplicate visible rows.

## Tasks

### 1. Document the feature

- [x] Add the product spec and this active execution plan.
- [x] Update the documentation maps and decision log.

### 2. Fetch bounded workout prefixes

- [x] Add a `HealthManager` query that returns the newest `limit` workouts sorted by end date, without fetching route or heart-rate data.
- [x] Add browsing state that grows the query limit until it has the requested number of category matches plus one lookahead match or exhausts the store.
- [x] Derive category matches through `VerveActivityMapper`, and identify displayed workouts by UUID to avoid duplicates.
- [x] Discard stale query results after a filter or refresh change; preserve the existing list on failure.

### 3. Build the activity browser

- [x] Show the newest matching workout in a latest section with the same compact export icon as history rows.
- [x] Group remaining compact rows by local month and keep existing debug/export actions.
- [x] Add the Verve type menu, one-tap clear control, Show more, progress, empty, and error states.
- [x] Keep ten total visible matches initially and add ten per Show more request.

### 4. Validate and close

- [x] Run `make validate-docs`, `make validate-lint`, and `make validate-build` or document environment restrictions.
- [x] Inspect the final diff and confirm no export format, permission, or project setting changes.
- [x] Update `docs/TESTING.md` with a real-device browser smoke check.
- [x] Move this plan to `completed/` and update `docs/exec-plans/README.md`.

## Progress Log

- 2026-09-28: Design approved in conversation; execution plan started.
- 2026-09-28: Implemented bounded prefix queries, Verve type filtering, latest activity row, month sections, Show more, and clear actions.
- 2026-09-28: `make validate-docs`, `make validate-lint`, `make validate-build`, and `git diff --check` passed. Lint normalization added final newlines to three existing SVGs and required one existing test-line formatting fix.
- 2026-09-28: Read-only review identified leap-month grouping and obsolete background category scans; both were corrected and the validation commands passed again. Real-device HealthKit behavior remains a manual smoke check.
- 2026-09-28: Real-device feedback showed the latest row's Export label wrapping vertically on a phone. Reused the compact icon-only row action for the latest workout and updated the acceptance check.
- 2026-09-28: After removing the label, `make validate-docs`, `make validate-lint`, `make validate-build`, and `git diff --check` passed. The changed row has not yet been inspected on a device.

## Completion Criteria

- The feature behavior in the linked product spec is implemented.
- The safest relevant validation commands are run or their limits are recorded.
- The completed plan and documentation maps reflect the final implementation.
