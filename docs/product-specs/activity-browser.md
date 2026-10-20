# Activity Browser

## Purpose

Make exporting the newest workout immediate while helping a new user find older workouts one at a time.

## Behavior

- Choose the latest workout by end date. Within each month section, show older workouts in descending order of end date.
- Initially show at most ten workouts. Place the newest matching workout in a `Latest activity` section with the same compact row layout and export icon as the history. Show each workout only once.
- Show the remaining workouts in compact rows grouped by the workout start date's month in the device's current calendar and time zone.
- `Show more` reveals up to ten additional matching workouts. Hide it when no older match exists.
- The filter defaults to `All activities` and uses the top-level `type` values from `VerveActivityMapper`: Cycling, Foot Sports, Swimming, Winter Sports, Strength Training, Indoor Cardio, Fitness & Flexibility, Climbing, and Other.
- Applying a filter affects both the latest section and the history. Match workouts before applying the ten-workout display limit. Keep the selected type visible in the filter control.
- When a type is selected, show a one-tap clear button beside the filter. The filter menu also contains `All activities`. Clearing returns to All activities and the newest ten workouts.
- When the selected type has no workouts, show an empty state with a `Clear filter` action. When there are no workouts at all, show a general empty state.
- Pull to refresh reloads the current filter from the newest workout and resets the displayed count to ten.
- Keep the existing one-workout export, debug preview, share sheet, and export error behavior. Add [bulk selection and export](bulk-export.md); filters and refresh are unavailable during selection, while Show more preserves selected UUIDs.
- Use the Verve orange accent color (`#F57A07`) for tinted controls and export icons. Use dark green (`#778332`) for workout activity icons so they are distinct from export actions.
- Use light green (`#EFF3DB`) for the activity screen background and white for workout rows. Omit the large `Activities` title. Show section headings in brown (`#6D5239`) and present this screen in light appearance.

## Loading And Failure States

- Show progress during the initial query and while requesting more workouts. Do not request route or heart-rate samples until an individual export or debug preview needs them.
- A failed refresh leaves the previously displayed list visible and reports the error. A failed `Show more` leaves the current page visible and allows a retry.
- HealthKit can return an empty list when access is denied or no workouts exist, so the empty state must not claim a specific cause.

## Acceptance Checks

- The latest workout can be exported directly from the first section.
- Selecting Swimming finds the newest swims even if the newest ten workouts overall contain no swims.
- Every displayed workout appears once; month headings reflect the user's local calendar.
- `Show more` adds at most ten matches and disappears at the end of history.
- Clearing a filter from its one-tap control or the empty state returns to All activities.
