# Sub-agent orchestration (Claude Code)

Used by `/plan`, `/bug`, `/qa`, `/feature`. Sub-agents cannot call or talk to each other; all coordination goes through the main session (orchestrator) and files on disk.

## 1. Who does what
- **Executors** (may edit source after the user approves): `@frontend-expert`, `@test-engineer`, `@devops-expert`.
- **Analysts** (analyze and recommend only): `@code-architect`, `@ts-security-auditor`, `@perf-expert`, `@business-analyst`, `@backend-expert`. Fixes an analyst finds are handed to an executor.
- `@git-sync-expert` only performs git operations at the ship step, after the user's separate confirmation.
- Per round: 1 lead + at most 3 supporting agents; a lead who edits code must be an executor. Run in parallel only independent work with no shared state.
- Before the user approves: agents only read, or write to their own evidence directory.

## 2. Working directory
The orchestrator creates the directories before calling agents and passes each agent an **absolute path**; agents never pick their own path, and stop and report if none was given.
```
.claude/work/<YYYY-MM-DD>-<slug>/
  plan.md
  evidence/
    <agent>[-<n>]/      one directory per instance: baseline/ repro/ before/ after/
    design/             written by the main session: Figma screenshot, nodes, assets
      context/          full get_design_context response; agents read only
```

## 3. Verify after every parallel phase
- Before the phase record `git status --porcelain`; after it, compare. Only new files under `evidence/` are allowed. Any other change (including extra edits to already-dirty files, or `.claude/settings.json`) ⇒ stop and tell the user.
- This is the real guard: analysts lack `Edit` but still have `Write` and `Bash`, so technically they can write any file.
- Limitation: gitignored files (`.env`, `node_modules`) are invisible to this check.

## 4. A/B and performance
- Enable A/B (plan states `A/B: yes | no — reason`) when: > 15 files or > 500 lines changed; global styles or widely shared components touched; a major dependency upgraded; or the user asks.
- Write `Base: <sha>` next to the `A/B:` line when the plan is written. Baseline A is built from a git worktree outside the repo at exactly that sha, never from HEAD or the working tree. No `Base: <sha>` ⇒ stop and ask.
- Each parallel instance uses its own dev-server port and build directory.
- Never run performance measurements in parallel: run sequentially, 3 times, take the median.

## 5. Report format
Every agent returns exactly 4 sections: `## Conclusion` (≤ 5 lines), `## Evidence`, `## Risks / out of scope`, `## Needs from other agents`. The orchestrator reads the last section to decide the next round. `@backend-expert` Advisory Notes are reference only: they go in the plan's "Backend notes" section and become tasks only if the user picks them at approval.
