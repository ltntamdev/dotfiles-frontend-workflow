---
description: Quality check of the output; QA level 1 by default, level 2 (A/B against a baseline) only when the plan says A/B yes
---

You are running QA for this request/change:
"$ARGUMENTS"

Follow the core AGENTS.md and `~/.claude/orchestration.md`. The full suite must be green; never skip or delete tests. Determine the project's real test, lint, and type-check commands (from the project's `AGENTS.md`, scripts); never assume.

## Level 1 — Standard QA (default)
- Use **1** `@test-engineer`: full test suite + lint + type-check; read the results.
- New logic must have tests; bug tasks add a regression test (fails before the fix, passes after).
- No worktree, no parallel runs.

## Level 2 — A/B QA (only when regression risk is real)
Run only when the plan says `A/B: yes`. Triggers:
- large change: **> 15 files or > 500 lines**;
- global styles (theme tokens, global CSS, root layout) or widely shared components touched (blast radius from CodeGraph, determined by `@code-architect`);
- a major dependency upgrade;
- the user asks (the user can switch it on/off at approval).

How (A = baseline, B = changed):
1. **Baseline A** is captured when planning: a worktree outside the repo at the plan's `Base: <sha>`, results in `evidence/test-engineer-1/baseline/`. If missing, build it now **from that exact `Base: <sha>`**; no `Base: <sha>` ⇒ stop and ask; never use HEAD or the working tree being edited.
2. **Run B** with 2–3 parallel `@test-engineer` instances, each with its own evidence directory, dev-server port, and build directory:
   - **TE-1:** full suite + lint + type-check on B.
   - **TE-2:** compare UI/behavior A vs B (screenshots, main flows).
   - **TE-3 (optional):** E2E, or re-run A to measure noise.
3. **Verify:** compare `git status --porcelain` before/after the parallel phase (orchestration §3); only new files under `evidence/` are allowed; anything else ⇒ stop and tell the user.
4. **Merge results** into an A vs B table (tests, screenshots, differences). Any unexplained difference ⇒ **do not ship**.

**Performance:** never measure in parallel (CPU contention skews results). Measure sequentially, 3 runs, take the median.

## Result
Report in the 4-section format (orchestration §5); state the level run, the commands used, and the evidence paths. Tests not 100% passing ⇒ do not hand off.
