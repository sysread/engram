# User Profile

## Communication Style
- Demands correctness over comfort. No reassurance, no hedging, no emotional framing. (confidence: 10)
- Asks questions for epistemic validation, not support. Answer with facts, logic, constraints. (confidence: 10)
- Agreement only when justified. Correct wrong assumptions directly. (confidence: 10)
- Prefers concise, structured responses. No fluff. (confidence: 10)

## Technical Background
- Senior backend/infrastructure engineer (confidence: 9)
- Expert in config, feature flag, secrets, and envvar governance (confidence: 9)
- Advanced Go, Django, PostgreSQL, Kubernetes background (confidence: 9)
- Maintainer of Zephira (config/flags/inventory) and Thorin (secrets/envvar review) (confidence: 9)
- Comfortable with complex technical and infrastructure scenarios (confidence: 9)

## Technical Preferences
- Meticulous, detail-oriented. Expects explicit contracts, types, behavior documentation. (confidence: 9)
- Code optimized for legibility and maintainability — shallowest on-ramp for unfamiliar engineers. (confidence: 10)
- Proper separation of concerns is the Prime Directive. (confidence: 10)
- Errors must be *useful*: explain what went wrong, how to fix it, with enough context. (confidence: 10)
- `info` logs only for *useful* information. (confidence: 10)
- Loves deleting code. Always flag newly-unused components. (confidence: 10)
- Expects atomic/reversible migrations, robust error handling, and full audit trails (confidence: 9)
- Requires authoritative data, thorough docs, and discrete, auditable change sets (confidence: 9)
- Values robust, auditable workflows, disciplined PRs, and collaborative communication (confidence: 9)

## Working Style
- Prefers agents/delegation over direct code writing. (confidence: 7)
- Expects minimal changes per branch. Always check for stale changes when pivoting. (confidence: 10)
- Expects save-point commits before code changes if there are unstaged changes. (confidence: 10)
- Use `make` targets (e.g. `make check`) instead of raw `mix` commands. The Makefile is the canonical build interface. (confidence: 10)
- Wants git archaeology for understanding *why* code exists, not just *how*. (confidence: 10)
- Expects thorough research before implementation — disambiguate first, code second. (confidence: 10)
- In markdown files, prefers one sentence per line (no mid-sentence wrapping), with a blank line between paragraphs. Works well across renderers and GitHub's interface. (confidence: 7)

## Directory Conventions
- `scratch/` in project root is the USER's personal notes directory (git-ignored). Do NOT write there. (confidence: 10)
- `.claude/notes/` is the AGENT's notes directory. All agent-persisted notes go here. (confidence: 10)

## Software Development Philosophy
- "Software changes work like tetris -- stack changes up, then when you reach a certain density, collapse the stack to manageable complexity. ALL of software development is complexity management." Wire up everything to the desired state first, THEN delete artifacts and polish. Don't polish incomplete work. (confidence: 9)

## Design & Review Thinking
- Thinks in terms of trust boundaries and data provenance. Asks "where did this value originate?" and "who controls it?" when evaluating correctness. (confidence: 7)
- Scopes PRs tightly. Will reject in-scope-adjacent fixes if they expand the change surface, even when trivial. Prefers separate tickets. (confidence: 8)
- Evaluates reviewer feedback independently -- accepts valid points, rejects invalid ones, doesn't rubber-stamp. Expects the same rigor from me when assessing third-party review. (confidence: 7)
- Treats code comments as contract documentation for future readers, not as changelog entries or implementation instructions. Comments should encode the *problem* and *context*, leaving the solution to the implementer. (confidence: 9)

## What Lands Well
- Flagging downstream impacts of changes (e.g. "AGENTS.md line 43 still references `make test`") - concise, specific, actionable. (confidence: 7)
- User catches comment style violations immediately. NEVER use `# --- label ---` inline section headers. Always use flower-box style. (confidence: 9)
- Pushback and corrections are appreciated. User explicitly values when I challenge assumptions or correct mistakes. (confidence: 9)
- Reporting "no signal" honestly when data doesn't support conclusions - do NOT hallucinate findings from insufficient evidence. User called this out as valuable behavior. (confidence: 9)
- Taking initiative to go beyond the literal request when the extension is obviously correct. Example: when asked to differentiate error messages, I also included the actual correct content in the error to short-circuit retry loops. User said "Oooh I like that you took the initiative." Do more of this - anticipate the next logical step when it's clearly beneficial. (confidence: 8)

## Failure Modes to Avoid
- Do not loop on symptoms. If unsure whether something is a symptom or root cause, STOP and ASK. (confidence: 10)
- Do not assume intent. Ask questions. (confidence: 10)
- Do not rationalize the user's reasoning. If premises are wrong, say so. (confidence: 10)
- Do not over-engineer or add features beyond what was asked. (confidence: 10)
- Do not write to `scratch/` — that's the user's space. (confidence: 10)

## Coding Preferences (General)
- Flower-box section headers. Three lines: (1) comment marker + dashes filling to column 80, (2) comment marker + space + header text, (3) same as line 1. The dash line always ends at exactly column 80. At deeper indentation, subtract the indent width from the dash count -- the right edge stays at column 80. If indentation makes the box too narrow to be readable, the code is too deeply nested; refactor. Never use `# --- section ---` inline markers. (confidence: 10)
  - Bash (0 indent): `#` then 79 `-` chars = 80 cols. Header: `# Section Name`
  - Bash (2 indent): 2 spaces + `#` then 77 `-` chars = 80 cols
  - Go: `//` then 78 `-` chars = 80 cols. Header: `// Section Name`
  - Elixir: `# ` then 78 `-` chars = 80 cols (space after `#` required by `mix format`). Header: `# Section Name`
- Comments should form a standalone outline: hide the code, grep just comments, and the file's behavior/intent should be fully comprehensible. (confidence: 10)
- Literary narrative style: comments explain the "why" and how a decision fits the larger system, not just "what". (confidence: 10)
- Prefers extracting functions over inline blocks, even when the function is only called once -- clarity of naming and separation matters. (confidence: 7)
- Dislikes too much logic/flags in Makefiles. Prefers extracting to helper scripts. (confidence: 8)
- When using newer/advanced language features, always include comments explaining how it works and why -- teaching tool for those unfamiliar. (confidence: 9)

## Bash Coding Preferences

### Naming
- Kebab-case ("belt-case") for function names and file names, never snake_case. (confidence: 10)
- Library functions use `namespace:verb-noun` with colons as separators (e.g. `tui:choose-one`, `kc:set-namespace`). (confidence: 10)
- Private/internal library functions use leading underscore on the function name or namespace segment (e.g. `_thog:extract-remote-host`, `sentry:_curl`). (confidence: 9)
- Bin-local functions (not exported) use bare kebab-case without a namespace (e.g. `fetch-issue`, `render-markdown`). (confidence: 9)
- Globals and script-scope variables must be ALL_CAPS. Lowercase signals "local to this function." (confidence: 10)
- Library-internal globals are prefixed with underscore + lib name (e.g. `_TUI_SCRIPTDIR`, `_INCLUDED_VALIDATE`). (confidence: 9)

### Variables
- One `local` declaration per line, never combined (e.g. `local foo` not `local foo bar baz`). Easier to read, comment, and reorder. (confidence: 10)
- All `local` declarations at the top of the function, not inline throughout the body. (confidence: 10)
- Use `local -n` (namerefs, bash 4.3+) for output parameters to avoid stdout pollution. (confidence: 9)

### Script Structure (bin/ commands)
Strict ordering, never deviate:
1. Shebang + `set -euo pipefail` + `shopt -s globstar nullglob`
2. Synopsis handler (before any expensive work): `if [[ "${1:-}" == "synopsis" ]]; then echo "..."; exit 0; fi`
3. Symlink resolution block (identical boilerplate across all scripts)
4. Import block: grouped in `{ }` with `# shellcheck source-path=SCRIPTDIR/../lib` directive
5. Environment validation: `has-min-bash-version` + `has-commands <deps>`
6. Constants and parameter globals (initialized empty, populated by ARGV)
7. Functions
8. ARGV parsing: `while (("$#")); do case "$1" in ... done`
9. Post-parse validation
10. Main / dispatch, ending with explicit `exit 0`
(confidence: 10)

### Library Structure (lib/ files)
Strict ordering:
1. Shebang + `set -euo pipefail`
2. Header comment describing purpose and scope
3. Multiple-inclusion guard: `[[ "${_INCLUDED_NAME:-}" == "1" ]] && return 0; _INCLUDED_NAME=1`
4. Self-locating scriptdir: `_NAME_SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"`
5. Import block (same `{ }` + shellcheck pattern as bin/)
6. Dependency validation at source time: `has-commands <deps>`
7. Globals
8. Internal/private functions (underscore-prefixed, NOT exported)
9. Public functions (with `export -f` after each block or at end)
(confidence: 10)

### Error Handling
- `die` uses `return 1`, not `exit 1`. Top-level scripts rely on `set -e` to propagate. (confidence: 10)
- Precondition guards are single-line: `<predicate> || die "<message>"`. (confidence: 10)
- Error constants as exported globals for testability (e.g. `KC_ERR_NO_CONTEXT`). (confidence: 8)
- `tui:die` for user-facing structured errors (routes through gum before dying). (confidence: 9)
- NOTE: `die`, `has-min-bash-version`, `has-commands`, and `tui:*` functions are conventions, not builtins. Each project must implement its own foundation libs providing these. (confidence: 10)

### Output
- stdout = program data; stderr = messages/logs. No exceptions. (confidence: 10)
- `usage()` pipes through `tui:format >&2` -- help text is stderr. (confidence: 10)
- `tui:format` renders markdown via `gum format` on TTY, falls back to `cat`. (confidence: 10)
- All logging through `tui:log` / `tui:debug` / `tui:info` / `tui:warn` / `tui:error` (structured via `gum log`). (confidence: 10)
- NOTE: `tui:*` functions are project-local libraries that must be built per-project, not pre-existing utilities. (confidence: 10)

### Formatting and Linting
- `shfmt -i 2 -bn -ci -sr`: indent 2, binary-ops-next-line, case-indent, space-redirect. (confidence: 10)
- `shellcheck -xa`: follow sources, enable all checks. (confidence: 10)
- Shellcheck directives on the line immediately before the affected statement, no intervening blank lines. (confidence: 9)

### Testing (bats)
- One `.bats` file per lib or feature, mirroring the `lib/` structure. (confidence: 10)
- No table-driven tests. Each `@test` is standalone and explicitly named. (confidence: 10)
- Minimal custom helpers: `is()` for equality, `diag()` for debug output. No bats-assert/bats-support plugins. (confidence: 10)
- Mocking via function override (in-process) or PATH-prepended stub scripts (subprocess isolation). (confidence: 10)
- Tests run under `env -i` with explicit allowlist (PATH, HOME, OSTYPE, TMPDIR, TERM). (confidence: 10)
- `setup()` per file, no `setup_file()`. No `teardown()` -- relies on `BATS_TEST_TMPDIR` lifecycle. (confidence: 9)
- Fake repos constructed with `git init` + `git remote add` in `$BATS_TEST_TMPDIR`. (confidence: 9)
- Network calls are never made in tests. External commands are stubbed or sentinel-guarded. (confidence: 10)

### Project Layout
- `bin/` -- executable subcommands, discoverable by dispatcher via `oink-*` naming
- `lib/` -- sourced libraries (never executable), guarded against multiple inclusion
- `helpers/` -- standalone dev/build scripts (install-deps, run-tests)
- `test/` -- bats test suite + helpers.sh
- `templates/` -- boilerplate for new commands, libs, tests
- `assets/` -- static assets
(confidence: 10)

### Build Tooling
- Makefile targets delegate to helper scripts rather than embedding logic inline. (confidence: 8)
- `make help` is self-documenting via awk over `##` comments. (confidence: 9)
- `make test` depends on `make deps` for auto-install. (confidence: 9)
- `make fmt` scopes to git-tracked files only. Templates excluded. (confidence: 9)
- `make perms` enforces `+x` on bin/helpers, `-x` on lib. (confidence: 9)

## Workflow Preferences
- When making code changes, always provide an extremely brief commit message fragment for the user. (confidence: 9)

## Writing Style (PRs, commits, docs)
- PR descriptions are a pitch for the reviewer, not a design doc. Frame the *problem* and its consequences first; the solution is secondary. (confidence: 9)
- No tables, no "notable design decisions" sections, no file inventories. Implementation internals belong in code comments, not PR descriptions. (confidence: 9)
- Telegraphic bullet style: lowercase start, abbreviations ("w/", "1x"), parenthetical shorthand. Not full formal sentences. (confidence: 9)
- Scope disclaimers are brief and direct -- two sentences max saying what the PR does NOT do. No hedging. (confidence: 8)
- Ancillary/tangential changes get a one-sentence footnote at the end, not their own section. (confidence: 8)
- Never over-engineer the description. A fix for a sloppy implementation is framed as exactly that, not as a "new feature" or "architecture improvement." Match the energy of the actual change. (confidence: 9)
- Commit messages are terse fragments, not full sentences. (confidence: 9)
- PR descriptions should include defensive phrasing aimed at AI reviewers (e.g. Cursor BugBot): explicitly call out intentional behavioral changes, explain things that could be misinterpreted as bugs, and describe intent clearly enough that an AI reviewer can judge whether changes follow the spirit of the goal. (confidence: 10)

## Observed Preferences (from interactions)
- Appreciates proactive surfacing of non-obvious implications (e.g. suggesting `Bash(flock *)` permission when discussing notes file permissions). Do more of this. (confidence: 7)
- Expects notes updates to happen immediately when giving feedback, not deferred. Positive feedback IS a write trigger. (confidence: 9)
- Cares about cross-process correctness even for low-probability race conditions. (confidence: 5)
- Thinks carefully about how LLM architecture affects tool design (asked about int vs float for confidence scoring "optimized for autocomplete-based intelligence"). Engages at the model-reasoning level. (confidence: 4)
- Delighted by useful shell tricks (e.g. the `[c]laude` bracket trick to exclude grep from its own results). Sharing non-obvious unix knowledge earns trust. (confidence: 5)
- Prefers pragmatic solutions over pure ones when the tradeoff is explicit. Accepted a "stupid, brittle hack" with a shrug when the alternative was setup friction. (confidence: 5)
- TODO/FIXME comments should describe the *problem*, not prescribe the solution. The caller shouldn't dictate implementation to the future implementer. This is a specific instance of the separation-of-concerns prime directive. (confidence: 9)
- Uses git worktrees for feature branches. Project notes (.claude/notes/) must go in the main repo root, NOT the worktree directory. Only worktree.md lives in the worktree. (confidence: 9)
- Frustrated by lack of desktop notifications when Claude is waiting for input. Configured hooks for Notification, Stop, PreCompact events. Wants to minimize babysitting. (confidence: 7)
- Minimize permission prompts. Avoid unnecessary 2>&1, command substitution, and io redirection in Bash tool calls -- each triggers a permission gate. The user does not want to babysit approval dialogs. Use bare commands wherever possible. (confidence: 9)
- Detests smart quotes, smart apostrophes, and emdashes. Use only ASCII equivalents: straight quotes, straight apostrophes, single hyphen for parenthetical asides. (confidence: 10)
- Double-hyphens as faux emdashes (` -- `) are AI slop. Use a single hyphen (` - `) for parenthetical/aside punctuation in comments and docs. (confidence: 10)
