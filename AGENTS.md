# Shared rules for AI agents

Reply to the user in English. The project's own AGENTS.md / CLAUDE.md holds
project specifics (test commands, protected branches, PR branch…). On conflict,
the project file wins.

## 1. Approve before editing
- Before editing files or running state-changing commands (install packages,
  migrate, commit…): clarify the request if ambiguous (one question at a time)
  → propose the approach (files to change, how to verify) → wait for approval.
- Small, obvious changes: a one-line confirmation is enough.
- Reading code, searching, and running tests/lint need no permission.
- Approval covers only what was presented. Anything beyond it → stop and report.
- If the user has clearly said "just do it", do it without asking again.

## 2. Ponytail: write the least code
Before writing new code, stop at the first rung that solves the problem:
1. Can it be skipped entirely? (YAGNI)
2. Does the codebase already have a similar function/component? Reuse or
   extend it; never duplicate.
3. Standard library or a built-in platform feature.
4. An existing dependency. Never add a new dependency without asking.
5. Write the minimum code.
- Fix bugs at the root and check every caller; never patch symptoms.
- Shortest diff, fewest files. No refactoring outside scope, no wrappers or
  abstractions that add no value.
- Never be lazy about: understanding the data flow before editing, validating
  external input, error handling, following the user's explicit requests.

## 3. Git safety
- Never force push in any form; never rewrite pushed history
  (rebase, amend, reset --hard).
- Never push, merge, or open a PR into a protected branch (default main,
  master, develop, plus any branch the project declares).
- Ask for separate confirmation before every push, PR, and merge. Plan
  approval does not count as that confirmation.
- No --no-verify, never disable hooks. If a hook/CI fails, fix the cause.
- Never delete remote branches or tags.
- Never put secrets in code, commits, or logs. Stage exactly the files to
  commit; no blind `git add .`.

## 4. CodeGraph
- If the repo has `.codegraph/` at its root: use `codegraph_explore` (MCP) or
  `codegraph explore "<symbol or question>"` before grep/reading files.
- No `.codegraph/`: skip it; never run `codegraph init` yourself.
