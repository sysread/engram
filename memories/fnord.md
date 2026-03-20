# Fnord — Project Notes

## Overview
Fnord is an AI-powered code archaeology CLI tool, built as an Elixir escript. Single app (not umbrella). Version 0.9.6.

## Operational Context
- This repository IS the runtime for the assistant. Edits here change how the assistant behaves.
- Keep diffs small and covered by tests.
- ALWAYS run `make check` before finalizing (compilation warnings = errors).
- ALWAYS run `mix format` after edits.
- NEVER commit or push unless explicitly instructed.

## Conventions (from FNORD.md)

### Code Style
- Functions should do one thing well; prefer small, pure functions with clear behavior.
- Use `|>` to chain transformations.
- Prefer function heads over complex conditionals.
- Prefer function heads over complex or nested `Enum` iterators (each, reduce).
- Prefer pattern matching over guards. Do not use type guards unless *required* for functionality — they add complexity and confuse dialyzer.
- Do not use in-line conditionals (e.g. `if ..., do: ..., else: ...`).
- Do not use `alias` unless required.
- Avoid `@doc false` entirely. Just give functions a `@doc`.
- Public functions should have `@spec`.
- This is not a library; no external API stability concerns.

### Integration Points
- Integration points are where different abstraction levels meet (entry points into a module, at minimum).
- Use `with` at significant integration points to transition between lower-level concerns and higher-level logic.
- Translate errors into domain-specific errors — what matters to the *caller* at this level?
- Special cases handled at integration points, not buried in lower-level functions.
- Integration points always get `@doc`s explaining how they fit into the bigger picture.
- Integration points should have basic positive and negative path tests; add tests as edge cases manifest.
- When refactoring, consider whether code organization reflects ownership of concerns. If you centralize a concern, does the location reflect that?

### Comments
- Describe current behavior, NEVER describe a change currently being made.
- Walk the reader through how the code behaves and how it fits into the bigger picture.
- Do not describe bugs/issues in comments; fix the code, then align comments.
- Literary style: hiding the code should leave an outline of behavior and how it fits into the next abstraction level up.

### Testing
- Use `Fnord.TestCase` and helpers (`mock_project`, `tmpdir`).
- Prefer `async: false` for most tests (global state, GenServers).
- **Always** use `Settings.get_user_home()` for paths — never `System.user_home!()`.
- Unit tests should NEVER reach out on the network. Mock network calls.

### Compile-time vs Runtime
- Escript app — no built-in Elixir app config.
- Module attributes evaluate at compile time.
- Use `defp` functions for values that must reflect runtime or test settings.

### Persistence and Concurrency
- Atomic writes (temp file + rename). See `Settings.write_atomic!`.
- Use `FileLock` for concurrent access; prefer per-file locks.
- Separate concerns into distinct files.

### Build / Quality
- ALWAYS run `make check` before finalizing.
- Compilation warnings are errors.

## Module Organization
- `AI.Agent` — implementations of that behaviour
- `AI.Tools` — implementations of that behaviour
- `Services` — GenServers
- Prefer context modules called by integration/feature/behavior layers

## Architecture Layers (bottom-up)

1. **Foundation**: Settings (JSON persistence + FileLock), Services.Globals (ETS-backed dynamic scoping), Util.*
2. **Infrastructure**: Store (project/file/conversation persistence), Memory (global/project/session learning), UI (Queue + Output behaviour), HttpPool, GitCli
3. **Services (GenServers)**: Globals, NamePool, Approvals (+Gate), Conversation, Notes, BackupFile, TempFile, MCP, Once
4. **AI Core**: Model (OpenAI GPT-5/4.1/o4), Endpoint (HTTP+retry), Embeddings (text-embedding-3-large), Completion (conversation orchestration + tool dispatch), Accumulator (streaming)
5. **AI Tools**: 20+ built-in tools (AI.Tools behaviour), Frobs (user-defined, dynamically loaded), MCP Tools (protocol servers). All implement same behaviour. Centralized schema validation via AI.Tools.Params.
6. **AI Agents**: Agent behaviour + 15+ agents (Coordinator, Researcher, FileInfo, Spelunker, CodeMapper, Troubleshooter, Coding agents, Memory.Indexer, etc.)
7. **Commands**: Cmd behaviour → ask, config, conversations, files, frobs, index, notes, prime, projects, memory, replay, search, summary, torch, upgrade
8. **Entrypoint**: Fnord.main/1 → parse CLI → start services → dispatch command

## Key Design Patterns
- SafeJson wraps Jason throughout -- use SafeJson.encode/decode, not Jason directly. SafeJson.Serialize protocol replaces @derive Jason.Encoder on structs.
- Behaviour-based abstraction everywhere (Cmd, AI.Tools, AI.Agent, UI.Output, Indexer)
- Two-tier state: Services.Globals (session/ephemeral, ETS) vs Settings (persistent, JSON + FileLock)
- UI.Queue serializes all UI operations; `interact/1` groups atomic UI operations
- Dynamic module creation for Frobs and MCP tools (Module.create/3 at runtime)
- Toolbox composition: basic_tools() | with_rw_tools() | with_coding_tools() | with_web_tools() | with_task_tools()
- `with` chains for integration points; tagged tuples throughout
- Atomic file writes: temp file → rename (POSIX)
- Process tree context inheritance via Services.Globals.Spawn

## CLI Dispatch Flow
1. Fnord.main/1 parses args via Optimus
2. Converts subcommand to Cmd.<Module>
3. Sets globals (quiet, project, edit mode, auto-approve)
4. Starts HTTP pools (ai_indexer, ai_memory, ai_notes, ai_api)
5. Starts config-dependent services (NamePool, Approvals, MCP)
6. Checks requires_project?() constraint
7. Cmd.perform_command/4 → module.run/3

## Settings System
- File: ~/.fnord/settings.json
- Structure: { version, approvals: {shell:[], edit:[]}, frobs: [], projects: { name: { root, exclude, frobs, approvals, mcp_servers } } }
- Subsystems: Settings.Approvals, Settings.Frobs, Settings.MCP, Settings.Migrate
- Project resolution: --project flag > ResolveProject.resolve() (CWD → git root → match settings)
- Runtime selection: Services.Globals.put_env(:fnord, :project, name)

## Testing (Details)
- Fnord.TestCase: temp HOME, mock_project/1, capture_all/1, Services started per test
- quiet: true by default (prevents interactive prompts)
- UI.Output.TestStub swapped in for UI.Output.Production
- MockIndexer, StubApprovals, no API keys (no network)
- Conventions: async: false, no aliases in test modules, mirror lib/ structure
- WARNING: UI.fatal calls System.halt(1) — hangs under capture_io. Tests must not hit error paths through run/3.

## Important Files
- FNORD.md — developer conventions (read this before contributing)
- lib/fnord.ex — entrypoint, CLI parsing, service startup
- lib/cmd.ex — Cmd behaviour + shared option defs
- lib/settings.ex + lib/settings/ — persistence layer
- lib/services/ — GenServer services
- lib/ui.ex + lib/ui/ — UI abstraction (Queue, Output behaviour, Formatter)
- lib/ai/ — AI core (completion, tools, agents, models, endpoint)
- lib/ai/tools/params.ex — centralized JSON Schema validation/coercion for all tool args
- lib/frobs.ex + lib/frobs/ — user-defined tool system
- lib/mcp/ — Model Context Protocol integration
  - Uses hermes_mcp library. Each MCP server gets a Hermes.Client.Supervisor (named `:"mcp:sup:<server>"`) and a Hermes.Client.Base GenServer (named `:"mcp:<server>"`). These names MUST differ because the supervisor holds its name while starting children.
  - `MCP.Supervisor.instance_name/1` returns the Base (client) name — used by callers to interact with the MCP client directly.
  - `MCP.Supervisor.supervisor_name/1` returns the Hermes supervisor name — only used internally during startup.
  - lib/services/mcp.ex — tool discovery, capabilities, server status (calls Base directly by registered name)

# Frobs Subsystem Notes

## What Is a Frob?
User-created external executable tools (bash, Python, anything) that fnord AI agents can call. Stored in ~/.fnord/tools/<name>/. Each has:
- spec.json — OpenAI function calling spec (parsed with keys: :atoms via Jason)
- main — executable (755), receives args via env vars
- available (optional) — exits 0 if frob is usable in current context

## Lifecycle
1. Create: Frobs.create/1 → writes spec.json + main + available templates
2. Enable: Settings.Frobs.enable(scope, name) — NOT auto-enabled on create
3. Load: Frobs.load/1 → validates files + spec → creates dynamic AI.Tools module
4. Execute: Frobs.perform_tool_call/2 → execute_main/2 → System.cmd with env vars
5. Availability: execute_available/1 (if script exists) AND Settings.Frobs.enabled?/1

## Environment Variables Passed to main
- FNORD_PROJECT — current project name
- FNORD_CONFIG — project settings as JSON
- FNORD_ARGS_JSON — tool arguments as JSON

## Dynamic Module Creation
Module.create/3 creates AI.Tools.Frob.Dynamic.<SanitizedName>_<MD5Hash>
Implements full AI.Tools behaviour. async?: true. All frobs are async tools.
read_args/1 is a passthrough ({:ok, args}) — validation happens centrally in AI.Tools.perform_tool_call via AI.Tools.Params.

## AI.Tools.Params (lib/ai/tools/params.ex)
Centralized JSON Schema validation/coercion for ALL tool call arguments (built-in tools, frobs, MCP tools).

### Public API
- validate_json_args/2: main entry point, called by AI.Tools.perform_tool_call. Accepts full tool spec (%{function: %{parameters: ...}}) or raw spec (%{parameters: ...}) or pre-normalized. Returns {:ok, coerced} | {:error, :missing_argument, msg} | {:error, :invalid_argument, msg}.
- normalize_spec/1: extracts parameters.properties + required into %{properties:, required:}
- normalize_schema/1: recursively normalizes schema maps (atom→string keys), including anyOf/oneOf/allOf sub-schemas, items, and nested properties
- param_list/1: sorted [{name, schema, required?}] tuples
- validate_and_coerce_param/2: type coercion (string, integer, number, boolean, null, array, object) + enum checks + composition dispatch
- validate_all_args/2: required check + coerce all values
- validate_prefilled_args/2: reject unknown keys + coerce known

### Composition Support
- anyOf: tries each sub-schema in order, returns first {:ok, _} match
- oneOf: tries ALL sub-schemas, requires exactly one match (strict exclusive)
- allOf: merge_schemas/1 then validate against merged (type=last wins, properties=deep merge, required=union, enum=intersection)
- Resolution order: type > anyOf > oneOf > allOf > error

### Introspection Helpers (used by Frobs.Prompt)
- resolve_schema_type/1: returns {:ok, type} | {:composition, keyword, sub_schemas} | {:error, :unresolvable}
- nullable_schema?/2: detects [type, null] 2-element patterns in anyOf/oneOf
- all_simple_types?/1: checks if all sub-schemas have simple type (string/integer/number/boolean)

### Notes
- normalize_spec handles both string and atom keys, but input always has atom keys (from Jason decode with keys: :atoms). String-key path is dead code. User plans to address separately.
- $ref/$defs are explicitly out of scope. Error message directs users to this limitation.
- coerce_string(nil) returns error (nil is not a string) — important for oneOf nullable patterns.

## Frobs.Prompt (lib/frobs/prompt.ex)
- prompt_for_params/2: walks spec, prompts user per parameter type
- Non-TTY/quiet mode: falls back to defaults only, errors on missing requireds
- Takes `ui` module as param (testable with mock)
- Simple types: enum→choose, boolean→choose(Yes/No), string/int/number→text prompt, array→loop, object→recursive
- Composition prompting (via resolve_schema_type dispatch):
  - Nullable anyOf/oneOf: prompt for non-null type with "optional, blank to skip"
  - Simple multi-type anyOf/oneOf: type chooser (UI.choose) then prompt for that type
  - allOf: merge schemas then prompt for merged result
  - Complex/fallback: raw JSON text input with parse + validate loop

## Settings.Frobs
- Scopes: :global | :project | {:project, name}
- Effective enabled: union of global + current project frobs
- Storage: settings.json top-level "frobs" array + projects.X.frobs array
- Atomic updates via Settings.update/4 with FileLock

## Cmd.Frobs (CLI)
- Subcommands: create, check, list, enable, disable, call
- call: interactive-only (prompts user for each parameter)
- run/3 wraps errors with UI.fatal (System.halt) — tests must avoid error paths or will hang
- Error contract: call_frob must return {:error, string} not {:error, tuple} for run/3 interpolation

## Spec Validation (validate_spec_json/2)
- name must match directory name
- description non-empty
- parameters.type must be "object"
- parameters.properties must be map
- parameters.required must be array of strings (defaults to [] if absent), all present in properties
- Each property must have EITHER:
  - type (in @allowed_param_types: boolean, integer, number, string, array, object, null) — validates type value
  - OR a composition keyword (anyOf, oneOf, allOf) — validates it's a non-empty list of maps
  - Both type AND composition keyword is also valid (type takes precedence for resolution)
- All properties must have non-empty description
- $ref/$defs: explicitly unsupported, error message says so

## Integration with AI
- Frobs.module_map/0 → merged into AI.Tools.basic_tools() toolbox
- AI.Completion dispatches tool calls to frob modules same as built-in tools
- AI.Tools.perform_tool_call validates args centrally via AI.Tools.Params.validate_json_args before calling any tool's call/1
- Frob specs get a note appended: "user-developed tool"
- ui_note_on_result truncates output >10 lines

## Known Style Debt
- validate_spec_json uses a long cond chain; could be refactored to pipeline of small validators
- Error tuple shapes are inconsistent across the params/prompt/frobs boundary (3-tuple, 2-tuple, nested tuple, bare atom)
- execute_main/2 uses integer (not atom) as 2nd element of 3-tuple error
