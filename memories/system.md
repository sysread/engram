# System Tools

## Confirmed Available
- `gcloud` - Google Cloud CLI
- `kubectl` - Kubernetes CLI
- `gh` - GitHub CLI
- `docker` / `docker compose` - Container management
- `rg` (ripgrep) - Fast code search
- `jq` - JSON processing
- `brew` - Homebrew package manager
- `fnord` - Elixir-based AI CLI for code archaeology, notes, playbooks (project tool)
- `perl` - Available system-wide; useful for Unicode-aware text processing
  - Replace smart quotes/apostrophes/emdashes with ASCII: `perl -CSD -pi -e 's/\x{201C}/"/g; s/\x{201D}/"/g; s/\x{2018}/'"'"'/g; s/\x{2019}/'"'"'/g; s/\x{2014}/--/g; s/\x{2013}/-/g;' FILE`
  - Verify none remain: `perl -CSD -ne 'print "$.: $_" if /[\x{201C}\x{201D}\x{2018}\x{2019}\x{2014}\x{2013}]/' FILE`
- `flock` - File locking utility (installed via `brew install util-linux`)

## Session Startup Checklist
- Always look for FNORD.md (or similar project convention files) at the start of a new conversation.
- Incorporate any conventions found into the project-level notes (at the PROJECT ROOT, not the worktree) if they have not already been incorporated.
