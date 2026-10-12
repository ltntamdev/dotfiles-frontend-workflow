#!/usr/bin/env bash
# Runs install.sh against a fake HOME (temp dir); checks install/uninstall never touches user files.
# Usage: bash scripts/test-install.sh
set -u
SRC="$(cd "$(dirname "$0")/.." && pwd -P)"
T=$(cd "$(mktemp -d)" && pwd -P)   # physical path (macOS: /var → /private/var), matches install.sh's pwd -P
trap '[ -n "$T" ] && [ -d "$T" ] && rm -rf -- "$T"' EXIT

FAILS=0
ok() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; FAILS=$((FAILS + 1)); fi; }

# Repo copy lives in a path with a space.
R="$T/repo with space"
mkdir -p "$R"
cp -R "$SRC/AGENTS.md" "$SRC/claude" "$R/"
cp "$SRC/install.sh" "$R/" 2>/dev/null

# snap <dir>: lists every entry (symlink + target, file + shasum, dir), sorted.
snap() {
  (cd "$1" && find . | LC_ALL=C sort | while IFS= read -r f; do
    if [ -L "$f" ]; then echo "L $f $(readlink "$f")"
    elif [ -f "$f" ]; then echo "F $f $(shasum < "$f" | cut -d' ' -f1)"
    else echo "D $f"; fi
  done)
}
# run <home> [args]: runs install.sh from outside the repo; output in $T/out, exit code in $T/rc.
run() { local h=$1; shift; (cd "$T" && HOME="$h" bash "$R/install.sh" "$@") > "$T/out" 2>&1; echo $? > "$T/rc"; }
entry() { echo "$1" | grep -F " ./$2 " ; }

# --- case_main: user files already present, some agents not installed
H="$T/home"
mkdir -p "$H/.claude/agents" "$H/.claude/commands" "$H/.codex" "$H/.gemini" "$H/.grok"
printf '# mine' > "$H/.claude/CLAUDE.md"
echo mine > "$H/.claude/agents/my-agent.md"
ln -s /nonexistent/qa.md "$H/.claude/commands/qa.md"
echo "codex own" > "$H/.codex/AGENTS.md"
BEFORE=$(snap "$H")

run "$H"
ok "main: exit 1 on warn" '[ "$(cat "$T/rc")" = 1 ]'
ok "main: warn for .codex/AGENTS.md" 'grep -q "^warn: .*\.codex/AGENTS\.md" "$T/out"'
ok "main: warn for dangling commands/qa.md" 'grep -q "^warn: .*commands/qa\.md" "$T/out"'
ok "main: skip junie" 'grep -q "^skip: .*\.junie" "$T/out"'
ok "main: ~/.junie not created" '[ ! -e "$H/.junie" ]'
ok "main: gemini link" '[ "$(readlink "$H/.gemini/AGENTS.md")" = "$R/AGENTS.md" ]'
ok "main: grok link" '[ "$(readlink "$H/.grok/AGENTS.md")" = "$R/AGENTS.md" ]'
ok "main: orchestration link" '[ "$(readlink "$H/.claude/orchestration.md")" = "$R/claude/orchestration.md" ]'
for f in "$R"/claude/agents/*.md; do
  n=${f##*/}; ok "main: agent $n link" '[ "$(readlink "$H/.claude/agents/$n")" = "$f" ]'
done
ok "main: all 9 agents linked" '[ "$(find "$H/.claude/agents" -type l | wc -l | tr -d " ")" = 9 ]'
for c in plan bug feature; do
  ok "main: command $c link" '[ "$(readlink "$H/.claude/commands/$c.md")" = "$R/claude/commands/$c.md" ]'
done
AFTER=$(snap "$H")
for p in .codex/AGENTS.md .claude/agents/my-agent.md .claude/commands/qa.md; do
  ok "main: $p unchanged" '[ "$(entry "$AFTER" "$p")" = "$(entry "$BEFORE" "$p")" ]'
done
ok "main: CLAUDE.md keeps its first line" '[ "$(head -1 "$H/.claude/CLAUDE.md")" = "# mine" ]'
ok "main: import block on its own line" 'sed -n 2p "$H/.claude/CLAUDE.md" | grep -q "^<!-- dotfiles-frontend-workflow:begin"'
ok "main: import line has no repo path (space-safe)" 'grep -qxF "@~/.claude/AGENTS.md" "$H/.claude/CLAUDE.md"'
ok "main: ~/.claude/AGENTS.md link" '[ "$(readlink "$H/.claude/AGENTS.md")" = "$R/AGENTS.md" ]'

run "$H"
ok "main: second run adds no duplicate" '[ "$(grep -c "dotfiles-frontend-workflow:begin" "$H/.claude/CLAUDE.md")" = 1 ]'

run "$H" --uninstall
ok "main: uninstall restores the pre-install state" '[ "$(snap "$H")" = "$BEFORE" ]'

# --- case_fresh: empty ~/.claude
H="$T/fresh"
mkdir -p "$H/.claude"
BEFORE=$(snap "$H")
run "$H"
ok "fresh: exit 0" '[ "$(cat "$T/rc")" = 0 ]'
ok "fresh: CLAUDE.md holds only the import block" '[ "$(grep -vc "dotfiles-frontend-workflow:" "$H/.claude/CLAUDE.md")" = 1 ] && grep -qxF "@~/.claude/AGENTS.md" "$H/.claude/CLAUDE.md"'
run "$H" --uninstall
ok "fresh: uninstall restores the pre-install state" '[ "$(snap "$H")" = "$BEFORE" ]'

# --- case_broken_marker: user deleted the end marker
H="$T/broken"
mkdir -p "$H/.claude"
printf 'a\n<!-- dotfiles-frontend-workflow:begin -->\n@x\nb\n' > "$H/.claude/CLAUDE.md"
BEFORE=$(snap "$H")
run "$H" --uninstall
ok "broken: CLAUDE.md untouched" '[ "$(snap "$H")" = "$BEFORE" ]'
ok "broken: warns" 'grep -q "^warn: .*CLAUDE\.md" "$T/out"'

# --- case_dangling_claude: CLAUDE.md is a dangling symlink
H="$T/dangling"
mkdir -p "$H/.claude"
ln -s "$T/nowhere/CL.md" "$H/.claude/CLAUDE.md"
BEFORE=$(snap "$H")
run "$H"
ok "dangling: exit 1" '[ "$(cat "$T/rc")" = 1 ]'
ok "dangling: warn for CLAUDE.md" 'grep -q "^warn: .*CLAUDE\.md" "$T/out"'
ok "dangling: target file not created" '[ ! -e "$T/nowhere/CL.md" ]'
run "$H" --uninstall
ok "dangling: uninstall restores the prior state" '[ "$(snap "$H")" = "$BEFORE" ]'

# --- case_fail: write failures must warn and exit 1
H="$T/fail"
mkdir -p "$H/.claude"
ln -s /nonexistent/agents "$H/.claude/agents"
printf 'ro\n' > "$H/.claude/CLAUDE.md"; chmod 444 "$H/.claude/CLAUDE.md"
run "$H"
ok "fail: exit 1 when a link/write fails" '[ "$(cat "$T/rc")" = 1 ]'
ok "fail: warn for agents" 'grep -q "^warn: .*agents" "$T/out"'
ok "fail: warn for read-only CLAUDE.md" 'grep -q "^warn: .*CLAUDE\.md" "$T/out"'
ok "fail: no link reported for agents" '! grep -q "^link: .*agents/" "$T/out"'
chmod 644 "$H/.claude/CLAUDE.md"

[ "$FAILS" -eq 0 ] || { echo "== $FAILS check FAIL =="; exit 1; }
echo "== all PASS =="
