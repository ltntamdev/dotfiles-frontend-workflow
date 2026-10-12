# dotfiles — shared rules for AI coding agents

> This is just my personal dotfiles.

One minimal `AGENTS.md` for Claude Code, Codex, Junie, Antigravity, and Grok, installed once per user via symlinks. Edit here, `git pull`, and every agent picks it up. Agent-facing files are in English to save tokens; agents reply in English by default.

**Reply language:** edit line 3 of `AGENTS.md` to `Reply to the user in <language>.` (e.g. `Vietnamese`, `Japanese`). Keep the rest of the file in English.

## Layout

```
AGENTS.md      core rules: approve before editing, Ponytail, git safety, CodeGraph
claude/        optional Claude Code extras: orchestration.md, 9 sub-agents, /plan /bug /qa /feature
templates/     project-AGENTS.md, settings.json (deny list), pre-push hook
install.sh     install / uninstall symlinks
scripts/       validate.sh, test-install.sh
```

## Install

```bash
git clone <repo> ~/dotfiles && bash ~/dotfiles/install.sh
```

Links `AGENTS.md` into `~/.codex/`, `~/.junie/`, `~/.gemini/`, `~/.grok/`, and `~/.claude/` (imported from `~/.claude/CLAUDE.md`), plus the `claude/` extras into `~/.claude/`. Agents that aren't installed are skipped. Existing files are never overwritten — they're reported as `warn:` (exit 1); move them aside and re-run. Safe to re-run; `bash ~/dotfiles/install.sh --uninstall` removes only what it added.

## Per project

- Copy `templates/project-AGENTS.md` to the project root as `AGENTS.md` and fill it in; it wins over the core on conflict. For Claude Code, the project `CLAUDE.md` is just `@AGENTS.md`.
- Optional hard guards (other agents only get git safety as text): copy `templates/settings.json` to `.claude/settings.json` and `templates/pre-push` to `.githooks/pre-push`, run `git config core.hooksPath .githooks`, and enable GitHub branch protection.
- Migrating from the old copy-based setup: delete the project's `.claude/rules/` and `.claude/agents/` (project agents shadow global ones).

## Verify

- Claude Code: `/memory` shows `AGENTS.md`; `/agents` lists 9 agents.
- Grok: `grok inspect` lists `~/.grok/AGENTS.md` (if not, rename the target to `CLAUDE.md`).
- Codex / Junie / Antigravity: in a repo without `AGENTS.md`, ask for the git safety rules (Codex 0.77 skips the global file there — upgrade).
- Repo: `bash scripts/validate.sh`.

## License

[MIT](LICENSE)
