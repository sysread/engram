# Oink Project Notes

## Overview
Pluggable bash command dispatcher for internal dev tooling at TruffleSecurity.
Organizes debugging and systems inspection tools for local dev and cloud infra.
Repo: `trufflesecurity/oink` on GitHub.

## Structure
- `bin/` - Executable subcommands (`oink`, `oink-logs`, `oink-alert`)
- `lib/` - Sourced libraries (not executable); guarded against multiple inclusion
- `helpers/` - Helper scripts called by bin/ (e.g., `install-deps`)
- `templates/` - Boilerplate for new commands, libs, tests
- `assets/` - Static assets (skull.txt)
- `test/` - bats test suite

## Runtime Dependencies
bash 5+, jq, gum, stdbuf, curl, gcloud, kubectl

## Dev Dependencies
bats-core, parallel, shellcheck, shfmt
All dev tools (except bash) are version-pinned in `.mise.toml` and installed via `mise install`.

## Key Commands
- `mise run test` - Run all bats tests (parallel, 4 jobs) via `helpers/run-tests`
- `mise run lint` - Run shellcheck via test/lint.bats
- `mise run fmt` - Format with `shfmt -i 2 -bn -ci -sr`
- `mise run fix` - fmt + perms
- `mise run check` - lint + test combined
- `mise install` - Install all pinned dev tools

## Test Environment Isolation
- `helpers/run-tests` invokes bats under `env -i` with an explicit allowlist: PATH, HOME, OSTYPE, TMPDIR, TERM.
- This prevents the user's shell profile (THOG_ROOT, API tokens, etc.) from leaking into tests.
- If tests need a specific env var, they must set it explicitly in `setup()` or the `@test` body.
- New env vars consumed by library code will NOT be available in tests by default -- this is intentional.

## Conventions
- Symlink resolution pattern at top of every script
- Library guard pattern: `[[ "${_INCLUDED_NAME:-}" == "1" ]] && return 0`
- Grouped source blocks with shellcheck directives
- Namespace prefixes for functions: `kc:`, `auth:`, `sentry:`, `io:`, `tui:`, `str:`, `thog:`
- Kebab-case for function names and file names (not snake_case)
- Namerefs for output variables (bash 4.3+)
- Program data -> STDOUT; logs/messages -> STDERR
- No table-driven tests
- Literary comment style throughout
- Tests: one .bats file per lib/feature, `is()` helper for assertions

## Subcommands
- `oink` - Main dispatcher; discovers `oink-*` scripts in bin/ and PATH
- `oink-logs` - Stream GKE pod logs with interactive hierarchical selection (cluster->ns->app->pod->container)
- `oink-alert` - Fetch Sentry issue/event/rule data from Slack/Sentry URLs, output markdown or JSON
- `oink-webapi` - Exercise internal/external APIs against local thog docker-compose dev environment

## Libraries
- `base.sh` - Core validation: warn, die, has-min-bash-version, has-commands, require-env-vars
- `auth.sh` - GCloud/GKE authentication orchestration
- `kc.sh` - Kubernetes context/namespace/app/pod/container selection state machine with cascading resets
- `sentry.sh` - Sentry REST API wrapper (read-only); authenticated curl
- `sentry_url.sh` - Sentry URL parser; returns JSON with kind + contextual fields
- `strings.sh` - String utils: truncate, unescape-newlines
- `termio.sh` - Terminal I/O: TTY detection, line-buffering, ANSI stripping, flag checking
- `thog.sh` - Thog repo detection and navigation; locates trufflesecurity/thog via THOG_ROOT or cwd walk-up
- `tui.sh` - Terminal UI: structured logging (gum), spinners, interactive choosers, json-damnit

## Known Pitfalls
- `die()` in base.sh returns from *itself*, not the calling function. After `die` in a compound command, you must add an explicit `return 1`: `{ die "msg"; return 1; }`
- `thog:root` runs in a subshell when called via `$(thog:root)`, so variable caching inside it does NOT work. Callers that need the result multiple times should store it in a variable and reuse it, not call `thog:root` again (or call `thog:subdir` which internally calls `thog:root`).
- macOS `/var` is a symlink to `/private/var`. Any path comparisons involving tmpdir or git's `--show-toplevel` must resolve symlinks via `cd -P "$dir" && pwd`.
- `shfmt` flags must match between Makefile (`make fmt`) and user's editor config. Currently: `-i 2 -bn -ci -sr`. The `-sr` flag was added to match the user's nvim config at `~/.config/nvim/lua/shell.lua`.
