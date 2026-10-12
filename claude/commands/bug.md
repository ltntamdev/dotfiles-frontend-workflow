---
description: Fix a bug via reproduce → plan → fix → evidence → ship; the bug must be reproduced before planning
---

You are handling this bug:
"$ARGUMENTS"

Follow the core AGENTS.md and `~/.claude/orchestration.md`. Working directory: `.claude/work/<YYYY-MM-DD>-<slug>/` (plan.md + evidence/).

## Step 0 — Intake
- Summarize symptoms, environment, reproduction steps. If key information is missing, ask, one question at a time.

## Step 1 — Reproduce (read only, write to `evidence/`)
In parallel:
- **Repro** — `@test-engineer` (E2E/Playwright for UI bugs): write a **one-off** reproduction script/test, save logs/screenshots to `evidence/<agent>/repro/`. Flaky bug: run 3 times and record the rate. Do not add tests to source at this step.
- **Scout** — `@code-architect` (CodeGraph if `.codegraph/` exists): call path, callers, root-cause hypotheses.
- If the symptom may come from an API/SDK (network errors, wrong/missing data, odd status codes): add `@backend-expert` in parallel; its Advisory Note must place the root cause in **FE / BE / contract**.

Record `git status --porcelain` before the phase and compare after (orchestration §3): only new files under `evidence/` are allowed; anything else ⇒ stop and tell the user. The orchestrator creates the evidence directories and passes absolute paths to each agent.

> **Gate 1:** if the bug **cannot be reproduced**, **do not plan**. Stop, report what was tried and what information is needed.

## Step 2 — Plan
- `plan.md` per `/plan`, plus: *repro command*, *root cause*, *blast radius*, `A/B: yes | no — reason` with `Base: <sha>` (base commit, recorded now).
- Fix at the root function (Ponytail), never patch the symptom.
- If security or performance is involved: add a parallel read-only review by `@ts-security-auditor` / `@perf-expert` (also compare `git status --porcelain` before/after).
- `@backend-expert` Advisory Notes go in **"Backend notes"**. If the root cause is in BE or the contract: give 2 options (FE workaround within task scope, or wait for a BE fix) with pros/cons, **for the user to choose**.

> **Gate 2:** stop and wait for `Approve`/`Proceed`. No source edits before approval.

## Step 3 — Fix
- The agent making the fix must be an **executor** (orchestration §1). If the surveying agent is an analyst (e.g. `@perf-expert`), hand the fix to a suitable executor following the analyst's recommendation.
- Turn the repro script into a **regression test in source**; run it on the **unfixed** code → must fail, record in `evidence/test-engineer/before/`.
- Fix at the root; run again → pass, record in `evidence/test-engineer/after/`.

## Step 4 — Verify
- QA per `/qa`: level 1, or level 2 (A/B) if the plan says `A/B: yes`.
- Before/after table: repro fail → pass, full suite green.

## Step 5 — Close
- Update `plan.md`: tick the checklist, record verification results.

> **Gate 3 — ship conditions:** repro-before fails, repro-after passes, suite green. Missing any one ⇒ do not ship.

> **Gate 4:** **ask the user for separate confirmation before push/PR.** `Approve` at Gate 2 does not replace it.

## Step 6 — Ship
- `@git-sync-expert`: commit `fix(scope): …` with the evidence link, push/PR per git safety in the core AGENTS.md (section 3).
- `@git-sync-expert`: watch CI and report; merge only with separate confirmation.

## Escalation
- If the first fix breaks other tests, or 2 fixes fail: go back to Step 1 and use the `superpowers:systematic-debugging` skill; do not keep patching.
