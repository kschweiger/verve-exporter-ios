# Execution Plans

Execution plans are durable work plans for larger or riskier changes.

Small changes may use a lightweight plan in the agent session. Larger changes, multi-step work, architecture changes, HealthKit changes, or export format changes should create a plan under `active/` before implementation and move it to `completed/` when done.

## Plan Structure

Use this structure:

```text
Goal
Context
Constraints
Files likely to change
Validation commands
Progress log
Decisions
Questions to resolve
Completion criteria
```

## Directories

- `active/`: Plans currently being executed.
- `completed/`: Finished plans retained for future agents.
- `tech-debt-tracker.md`: Known debt, quality gaps, and follow-up work.
