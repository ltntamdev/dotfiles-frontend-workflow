---
description: Technical planning: parallel read-only survey (CodeGraph if present), write plan.md, stop for approval before editing code
---

You are planning the following request:
"$ARGUMENTS"

Follow the core AGENTS.md (section 1: approve before editing) and `~/.claude/orchestration.md`.

1. **Pick the lead**: by the sub-agents' `description`; a lead who edits code must be an executor. Up to 3 supporting agents may run in parallel in step 2.

2. **Survey (read only)**:
   - Repo has `.codegraph/`: use `codegraph_explore` or `codegraph explore "<symbol/question>"` for the call graph, callers, affected symbols. Otherwise use Grep/Glob/Read.
   - Create `.claude/work/<YYYY-MM-DD>-<slug>/`; supporting agents write only to their assigned `evidence/<agent>/`. Compare `git status --porcelain` before/after the phase (orchestration §3).
   - If the task qualifies for A/B: capture baseline A in parallel during this phase, from a worktree at `Base: <sha>`.

3. **Write `.claude/work/<YYYY-MM-DD>-<slug>/plan.md`** with:
   - Goal, lead and supporting agents.
   - Files to change, marked `[NEW]` / `[MODIFY]` / `[DELETE]`.
   - Task checklist `- [ ]`.
   - Exact verification commands (the project's test, lint, type-check).
   - A line `A/B: yes | no — reason` and a line `Base: <sha>` (base commit, recorded now).
   - 1–3 options with pros/cons and a recommendation.
   - A Mermaid diagram (`[NEW]/[MODIFY]/[UNCHANGED]`) when the change spans 2 or more layers (UI, hook, store, service…).
   - A **"Backend notes"** section (separate from the checklist) holding `@backend-expert` Advisory Notes; they become tasks only if the user picks them at approval.

4. **Stop and wait for approval**: link to `plan.md` and end the turn. Do not edit any code file until the user explicitly approves.
