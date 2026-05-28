# Harness Principles

## Operating Model

Humans steer; agents execute. The repository is the agent's map, memory, operating surface, and feedback loop.

## Principles

- `AGENTS.md` is an index, not a manual.
- Durable knowledge belongs in versioned repository-local docs.
- Rules that matter should become checks when practical.
- Agents need readable architecture, tests, logs, and feedback from validation commands.
- Plans, decisions, and debt must be recorded.
- Quality is maintained continuously, not in rare cleanup bursts.
- Secrets and personal HealthKit data must never be committed.
- Unknowns should be explicit. Do not invent facts to make docs look complete.

## Applying The Principles

When future agents learn a durable rule, repeated bug pattern, naming preference, unsafe command, HealthKit finding, or validation requirement, they must update the relevant docs in the same change set.
