#!/usr/bin/env bash
# Checks dotfiles structure: core AGENTS.md, Claude extras, templates, install.sh, external references.
# Usage: bash scripts/validate.sh [core|agents|agents-count|commands|refs-paths|templates|settings|install|refs|all]
set -u
cd "$(dirname "$0")/.."

FAILS=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAILS=$((FAILS + 1)); }
check() { if eval "$2"; then pass "$1"; else fail "$1"; fi; }
has() { grep -qF -- "$2" "$1" 2>/dev/null; }                  # has <file> <fixed string>
needs() { local f=$1; shift; for s in "$@"; do check "$f contains '$s'" "has '$f' '$s'"; done; }

ALL_AGENTS="frontend-expert backend-expert code-architect test-engineer perf-expert devops-expert ts-security-auditor business-analyst git-sync-expert"
ANALYSTS="code-architect ts-security-auditor perf-expert business-analyst backend-expert"
ORCH='~/.claude/orchestration.md'

frontmatter() { awk 'NR==1&&$0!="---"{exit} NR>1&&$0=="---"{exit} NR>1{print}' "$1"; }

group_agents() {
  local f n fm
  check "claude/agents directory exists" "[ -d claude/agents ]"
  for f in claude/agents/*.md; do
    [ -e "$f" ] || continue
    n=$(basename "$f" .md); fm=$(frontmatter "$f")
    check "$n: frontmatter starts with ---" "[ \"\$(head -1 '$f')\" = '---' ]"
    check "$n: name matches file name" "echo \"\$fm\" | grep -qx 'name: $n'"
    check "$n: description is one double-quoted line" "echo \"\$fm\" | grep -qE '^description: \"[^\"]+\"\$'"
    check "$n: has tools" "echo \"\$fm\" | grep -q '^tools: .'"
    check "$n: model: inherit" "echo \"\$fm\" | grep -qx 'model: inherit'"
    for h in '## Conclusion' '## Evidence' '## Risks / out of scope' '## Needs from other agents'; do
      check "$n: has heading '$h'" "grep -qxF '$h' '$f'"
    done
    check "$n: points to orchestration" "has '$f' '$ORCH'"
    check "$n: uses the shared evidence path" "has '$f' 'evidence/<agent>[-<n>]/'"
    case " $ANALYSTS " in *" $n "*)
      check "$n: analyst has no Edit" "! echo \"\$fm\" | grep '^tools:' | grep -qw Edit" ;;
    esac
    [ "$n" = frontend-expert ] && needs "$f" 'evidence/design/context/'
    [ "$n" = git-sync-expert ] && needs "$f" 'separate confirmation for the merge'
    if [ "$n" = backend-expert ]; then
      needs "$f" 'Advisory Note' 'Issue' 'Root cause' 'Impact on frontend' 'Suggestion' 'Who should fix' 'Confidence'
    fi
  done
}

group_agents_count() {
  local got want
  got=$(ls claude/agents/*.md 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/\.md$//' | sort | tr '\n' ' ')
  want=$(echo $ALL_AGENTS | tr ' ' '\n' | sort | tr '\n' ' ')
  check "exactly the 9 expected agents" "[ \"$got\" = \"$want\" ]"
}

group_commands() {
  local c f
  for c in plan bug qa feature; do
    f=claude/commands/$c.md
    check "$f has description" "[ -f $f ] && frontmatter $f | grep -q '^description: .'"
    needs $f "$ORCH"
  done
  needs claude/commands/bug.md 'Gate 1' 'Gate 2' 'Gate 3' 'Gate 4' 'cannot be reproduced'
  needs claude/commands/feature.md 'figma:figma-design-to-code' 'get_design_context'
  for c in plan bug feature; do needs claude/commands/$c.md '.claude/work/'; done
}

group_refs_paths() {
  local p bad
  for p in $(grep -rhoE '~/\.claude/[A-Za-z0-9_./-]+\.md' claude README.md 2>/dev/null | sort -u); do
    [ "$p" = '~/.claude/CLAUDE.md' ] && continue          # install target edited by install.sh, not a repo file
    [ "$p" = '~/.claude/AGENTS.md' ] && { check "reference $p exists in repo" "[ -f AGENTS.md ]"; continue; }   # symlink to the core
    check "reference $p exists in repo" "[ -f 'claude/${p#\~/.claude/}' ]"
  done
  for bad in '.claude/rules/' 'rules/0' '09-git-safety' '.claude/plans/' '@playwright-expert' '@release-manager' 'Sub-Agent Activated' 'Fast-Scan'; do
    check "no leftover '$bad'" "! grep -rnF --exclude-dir=.git --exclude-dir=docs --exclude-dir=.superpowers --exclude=validate.sh --exclude=README.md -- '$bad' . >/dev/null"
  done
}

group_core() {
  local h
  check "AGENTS.md exists" "[ -f AGENTS.md ]"
  check "AGENTS.md sets a reply language" "grep -qE '^Reply to the user in [A-Za-z]+\.' AGENTS.md"
  check "AGENTS.md ≤ 80 lines" "[ -f AGENTS.md ] && [ \"\$(wc -l < AGENTS.md)\" -le 80 ]"
  for h in '## 1. Approve before editing' '## 2. Ponytail: write the least code' '## 3. Git safety' '## 4. CodeGraph'; do
    check "AGENTS.md has '$h'" "grep -qxF '$h' AGENTS.md 2>/dev/null"
  done
}

group_templates() {
  needs README.md 'install.sh' '--uninstall' 'templates/project-AGENTS.md' 'grok inspect'
  check "templates/project-AGENTS.md exists" "[ -f templates/project-AGENTS.md ]"
  check "settings.json is valid JSON" "python3 -m json.tool templates/settings.json >/dev/null"
}

denied() {                                                     # denied <command>: matches a settings.json deny pattern?
  local p
  while IFS= read -r p; do
    # shellcheck disable=SC2053
    [[ "$1" == $p ]] && return 0
  done < <(python3 -c 'import json;[print(x[5:-1]) for x in json.load(open("templates/settings.json"))["permissions"]["deny"] if x.startswith("Bash(")]')
  return 1
}

group_settings() {
  local c
  for c in 'git push origin main' 'git push -u origin develop' 'git push origin HEAD:master' 'git push origin HEAD:refs/heads/main' 'git checkout main' 'git push --force origin x'; do
    check "deny blocks: $c" "denied '$c'"
  done
  for c in 'git push origin feature/maintenance' 'git push -u origin fix/main-menu' 'git checkout feature/domain' 'git merge main' 'git push origin chore/x'; do
    check "deny allows: $c" "! denied '$c'"
  done
}

group_install() {
  check "install.sh bash syntax" "bash -n install.sh"
  check "pre-push bash syntax" "bash -n templates/pre-push"
  check "test-install.sh: install/uninstall on a fake HOME" "bash scripts/test-install.sh >/dev/null 2>&1"
}

group_refs() {
  check "no leftover .claude/sub-agents path" "! grep -rn '\.claude/sub-agents' --exclude-dir=.git --exclude-dir=docs --exclude-dir=.superpowers --exclude=validate.sh . >/dev/null"
  check "no machine-specific paths" "! grep -rnE '/Users/|/home/[a-z]|~/Documents' --exclude-dir=.git --exclude-dir=.idea --exclude-dir=docs --exclude-dir=.superpowers --exclude=validate.sh . >/dev/null"
}

case "${1:-all}" in
  agents|sub-agents) group_agents ;;
  agents-count|sub-agents-count) group_agents_count ;;
  commands) group_commands ;;
  refs-paths) group_refs_paths ;;
  core) group_core ;;
  templates) group_templates ;;
  settings) group_settings ;;
  install) group_install ;;
  refs) group_refs ;;
  all) group_core; group_agents; group_agents_count; group_commands; group_refs_paths; group_templates; group_settings; group_install; group_refs ;;
  *) echo "unknown group: $1"; exit 2 ;;
esac
[ "$FAILS" -eq 0 ] || { echo "== $FAILS check FAIL =="; exit 1; }
echo "== all PASS =="
