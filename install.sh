#!/usr/bin/env bash
# Install the core AGENTS.md for AI agents (user-level symlinks) plus the Claude Code extras.
# Usage: bash install.sh [--uninstall]
# Never overwrites anything: an occupied target prints "warn:" and is skipped (exit 1).
set -u
REPO="$(cd "$(dirname "$0")" && pwd -P)"
MODE=install
[ "${1:-}" = --uninstall ] && MODE=uninstall
BEGIN='<!-- dotfiles:begin -->'   # variants: "begin nl" (added a trailing newline), "begin new" (created the file)
END='<!-- dotfiles:end -->'
WARN=0

say() { echo "$1: $2"; }
warn() { say warn "$1"; WARN=1; }

# link_one <src> <dst>
link_one() {
  if [ -L "$2" ] && [ "$(readlink "$2")" = "$1" ]; then say ok "$2"; return; fi
  if [ -e "$2" ] || [ -L "$2" ]; then warn "$2 already exists, skipped (move it aside and re-run)"; return; fi
  if ln -s "$1" "$2" 2>/dev/null; then say link "$2"; else warn "could not create $2"; fi
}

# unlink_one <src> <dst>: only removes symlinks pointing into this repo.
unlink_one() {
  [ -L "$2" ] && [ "$(readlink "$2")" = "$1" ] || return 0
  if rm "$2"; then say unlink "$2"; else warn "could not remove $2"; fi
}

claude_add() {
  local f="$HOME/.claude/CLAUDE.md" tag=$BEGIN
  if [ -L "$f" ] && [ ! -e "$f" ]; then warn "$f is a dangling symlink, skipped"; return; fi
  if [ -f "$f" ] && grep -q '^<!-- dotfiles:begin' "$f"; then say ok "$f"; return; fi
  if [ -e "$f" ] && [ ! -w "$f" ]; then warn "could not write $f"; return; fi
  if [ ! -e "$f" ]; then
    tag='<!-- dotfiles:begin new -->'
  elif [ -s "$f" ] && [ -n "$(tail -c1 "$f")" ]; then
    tag='<!-- dotfiles:begin nl -->'; printf '\n' >> "$f"
  fi
  if printf '%s\n@~/.claude/AGENTS.md\n%s\n' "$tag" "$END" >> "$f" 2>/dev/null; then say link "$f (import AGENTS.md)"; else warn "could not write $f"; fi
}

claude_remove() {
  local f="$HOME/.claude/CLAUDE.md" tag tmp
  [ -f "$f" ] || return 0
  tag=$(grep -m1 '^<!-- dotfiles:begin' "$f") || return 0
  if ! grep -qxF "$END" "$f"; then warn "$f is missing $END, not removed (fix by hand)"; return; fi
  tmp=$(mktemp)
  awk -v e="$END" 'skip && $0 == e { skip = 0; next } skip { next } /^<!-- dotfiles:begin/ { skip = 1; next } { print }' "$f" > "$tmp"
  if [ "$tag" = '<!-- dotfiles:begin new -->' ] && [ ! -s "$tmp" ]; then
    rm "$f" "$tmp" && say unlink "$f"; return
  fi
  if [ "$tag" = '<!-- dotfiles:begin nl -->' ]; then printf '%s' "$(cat "$tmp")" > "$f"; else cat "$tmp" > "$f"; fi \
    && say unlink "$f (import AGENTS.md)" || warn "could not write $f"
  rm -f "$tmp"
}

op=link_one
[ "$MODE" = uninstall ] && op=unlink_one

for d in .codex .junie .gemini .grok; do
  if [ -d "$HOME/$d" ]; then $op "$REPO/AGENTS.md" "$HOME/$d/AGENTS.md"; else say skip "$HOME/$d (not installed)"; fi
done

if [ ! -d "$HOME/.claude" ]; then
  say skip "$HOME/.claude (not installed)"
else
  if [ "$MODE" = install ]; then
    mkdir -p "$HOME/.claude/agents" "$HOME/.claude/commands" 2>/dev/null || warn "could not create $HOME/.claude/agents or commands"
  fi
  $op "$REPO/AGENTS.md" "$HOME/.claude/AGENTS.md"
  $op "$REPO/claude/orchestration.md" "$HOME/.claude/orchestration.md"
  for f in "$REPO"/claude/agents/*.md; do $op "$f" "$HOME/.claude/agents/${f##*/}"; done
  for f in "$REPO"/claude/commands/*.md; do $op "$f" "$HOME/.claude/commands/${f##*/}"; done
  if [ "$MODE" = install ]; then
    claude_add
  else
    claude_remove
    rmdir "$HOME/.claude/agents" "$HOME/.claude/commands" 2>/dev/null
  fi
fi

exit $WARN
