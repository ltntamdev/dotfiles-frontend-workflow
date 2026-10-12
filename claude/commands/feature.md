---
description: Build a frontend feature from a Figma design with parallel survey, plan, dependency-ordered implementation, design-match verification, and cross review
---

You are building this frontend feature:
"$ARGUMENTS"

Follow the core AGENTS.md and `~/.claude/orchestration.md`. Working directory: `.claude/work/<YYYY-MM-DD>-<slug>/`. Default lead: `@frontend-expert`. Use `/bug` for bug fixes.

## Step 0 — Intake
- Ask for scope, edge cases, and the **Figma link/node** of the screen or component. No link ⇒ ask; never guess.

## Step 1 — Read-only survey, in parallel
- **Read Figma (main session, once):** load the `figma:figma-design-to-code` skill, then call `get_design_context` with a screenshot; the skill name must be in the `skillNames` parameter. No screenshot ⇒ call `get_screenshot`. If the result is marked *sparse*: match child nodes against the screenshot and call `get_design_context` for the child nodes **in one parallel batch**.
- Save to `evidence/design/`: reference screenshot, node IDs, static asset list (**list only, do not download yet**), and the **full `get_design_context` response** to `evidence/design/context/`.
- **Figma not authenticated** (only the `authenticate` tool is visible) ⇒ **stop here and say so**; never guess the design.
- Alongside the Figma read, pick up to 3 read-only supporting agents (`@backend-expert` is mandatory when the task calls a backend API/SDK and counts toward the 3):
  - `@code-architect`: reusable components/hooks/utils/tokens, blast radius, component boundaries (< 200 lines).
  - `@business-analyst`: Gherkin acceptance criteria if a spec exists.
  - `@ts-security-auditor`: types, XSS, input data.
  - `@perf-expert`: if heavy pages, images, or the JS bundle are touched.
  - `@backend-expert`: writes Advisory Notes.
- If A/B applies (orchestration §4): capture baseline A in parallel.
- Record `git status --porcelain` before the phase and compare after (orchestration §3): only new files under `evidence/` are allowed; anything else ⇒ stop and tell the user. The orchestrator creates the evidence directories and passes absolute paths to each agent.

## Step 2 — Plan (`/plan`)
`plan.md` per `/plan`, plus:
- component tree (Mermaid, `[NEW]/[MODIFY]/[UNCHANGED]`);
- **Figma node → existing component mapping** (prefer reuse, follow Code Connect if present; create new only when the design cannot be expressed otherwise);
- **design tokens** for color, spacing, typography (no hardcoding);
- **asset list** with exact placement per the design;
- UI states (loading, empty, error), responsive, dark/light, a11y;
- `A/B: yes | no — reason` with `Base: <sha>` (base commit, recorded now); supporting agents; which agent owns which files;
- a **"Backend notes"** section with Advisory Notes (separate from the task checklist).

## Step 3 — Approval gate
- Stop and wait for `Approve`/`Proceed`. No source edits and no asset downloads into the project before approval. The user picks which Advisory Notes become tasks.

## Step 4 — Implement in dependency order
1. **Contracts:** types and props interfaces.
2. **Tests first:** `@test-engineer` writes tests from the acceptance criteria.
3. **Data layer:** hooks, services, stores, implemented by `@frontend-expert`; `@code-architect` only proposes boundaries and reviews.
4. **UI:** before assigning, the main session **calls `get_design_context` again** (so asset URLs are fresh), saves it to `evidence/design/context/`, and passes the path to `@frontend-expert` (which has no Figma tools). `@frontend-expert` builds **only from the high-fidelity `get_design_context` response**; converts absolute positioning to the project's flex/grid; interactive parts must actually be interactive. The screenshot is only a comparison target, never an asset.
5. **Assets:** download exactly as `get_design_context` instructs, place as designed; API-provided images/data stay dynamic; never edit/redraw/replace assets; no temporary Figma URLs; never override an SVG's original width/height.

Phase A runs these steps sequentially; phase B (parallel on disjoint files) is not enabled yet.

## Step 5 — Verify
- QA per `/qa`: level 1, or level 2 (A/B) if the plan says `A/B: yes`.
- **Design match:** screenshot the implementation at the same viewport as the Figma screenshot in `evidence/design/` and compare; only the requested screens/components count; pre-existing differences outside scope are noted, not fixed.
- **Asset checklist:** for every visible static asset: local file non-empty, correct design slot/layer, correct call site, correct displayed aspect ratio. One wrong asset is a FAIL; fix all in-scope issues before finishing.
- `@test-engineer` runs E2E on the main flows; checks dark/light and responsive; measures performance sequentially.

## Step 6 — Read-only review, in parallel
- `@code-architect` (size, clean code), `@ts-security-auditor`, `@frontend-expert` (a11y, tokens), and `@backend-expert` when there is API/SDK integration (both sides).
- The lead merges findings into a fix list, fixes, and repeats Step 5 if needed. Compare `git status --porcelain` before/after the review phase (orchestration §3).

## Step 7 — Close & ship
- Update `plan.md`: tick the checklist, record verification results.
- **Ask the user for separate confirmation before push/PR.** Then `@git-sync-expert` (push, PR, watch CI).
