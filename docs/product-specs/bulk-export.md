# Bulk Export

## Behavior

Select workouts in the current activity filter and share one Verve JSON file per workout in one native share sheet. Selection covers loaded rows only, including Latest activity. Select loaded selects all displayed workouts; Show more preserves selection and leaves new rows unselected. Deselect all clears selection. Cancel exits selection. Filters and refresh are disabled during selection.

Export (N) is disabled for zero selections. Export snapshots selected workouts in browser order, deduplicated by UUID. Process sequentially with immediate Preparing workout X of N progress and cancellation. No batch cap or background execution is provided.

All-success batches open sharing automatically. Partial/all failures show success/failure counts and workout type, date, and reason. Share successful files only after the user chooses Share N files. Preserve selection after results and share dismissal.

Each attempt owns an isolated temporary directory. Duplicate names gain deterministic -2, -3 suffixes before .json. JSON contents and existing individual exports remain compatible. Cancellation invalidates presentation immediately, finishes/discards any in-flight operation, and starts no further workout. Clean only the attempt directory after outstanding work finishes or sharing is dismissed. Never upload data or change HealthKit permissions.

## Acceptance

Selection, pagination, mixed/all failures, cancellation/retry, duplicate filenames, and scoped cleanup have synthetic coverage. Device checks cover accessibility, responsiveness, and multi-file sharing. Individual export remains available outside selection, and Select is disabled while an individual sheet is active.
