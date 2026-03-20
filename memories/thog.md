# Project: thog (TruffleHog Enterprise)

## Overview
Large monorepo for TruffleHog Enterprise — a secret detection platform. Contains multiple interdependent applications. Primary language is Go with a Django (Python) web application and React (TypeScript) frontend.

**Module**: `github.com/trufflesecurity/thog`
**Go Version**: 1.24.9
**Dependencies**: Vendored (`vendor/`)

## Repository Layout

```
thog/
├── api/            # Scanner API server (Go, gRPC)
├── scanner/        # Secret detection engine (Go)
├── gateway/        # HTTP gateway/reverse proxy (Go, chi)
├── web/            # Web backend (Django 4.2, DRF)
├── frontend/       # Web frontend (React 18, TypeScript, Vite)
├── muskie/         # Database test infrastructure (Go)
├── thogctl/        # Deployment/management CLI (Go)
├── e2e/            # End-to-end tests (Playwright)
├── tools/          # Build tool binaries
├── scripts/        # Deployment and utility scripts
├── hack/           # Infrastructure utilities (pubsub-init, config-gen)
├── vendor/         # Go vendored dependencies
├── postgres/       # Postgres init scripts
├── docs/           # Architecture diagrams, config docs
└── tags/           # (unknown)
```

## Architecture & Data Flow

```
External Sources (Git, AWS, GCP, GitHub, etc.)
         │
         ▼
   Scanner (Go) ──gRPC──▶ API Server (Go) ──▶ PostgreSQL
         │                      │
         │                      ▼
         │               Pub/Sub Broker ──▶ Analyzers ──▶ Notifications
         │
   Gateway (Go) ◀──── Frontend (React)
         │
   Django Web (Python) ◀── Auth, Models, External API
```

### Data Lineage: Secrets
Go ingestion → Django model → matview (PostgreSQL) → API/FE modeling.
All mapping and field transformations tracked in readmes and code comments.

### Service Ports (local dev)
| Service   | Port  | Debug Port |
|-----------|-------|------------|
| Django    | 8000  | 5678       |
| Gateway   | 9000  | 4002       |
| API       | 8001  | 4000       |
| Scanner   | 18066 | 4001       |
| Frontend  | 3000  | —          |
| Postgres  | 5432  | —          |
| pgAdmin   | 5050  | —          |
| Pub/Sub   | 8085  | —          |
| Mock IdP  | 8088  | —          |

## Key Applications

### api/ — Scanner API Server
- **Purpose**: Core gRPC/REST API. Manages scanning jobs, processes secrets, stores findings.
- **Entrypoint**: `api/cmd/server/main.go`
- **Key packages**: `apipb` (proto), `analyzepb`, `services`, `models` (SQLBoiler), `migrations`, `auth`, `messaging`, `metrics`, `query`, `analyze`, `forager`
- **ORM**: SQLBoiler (generated from Django schema)
- **Proto files**: `api/proto/` — `api.proto`, `pem_api.proto`, `analyze.proto`, `notifiers.proto`, `enterprise_config.proto`, `workflows.proto`
- **Generated Go code**: `api/pkg/*/pb/`
- **Health**: Exposes `/healthz` endpoint checking DB connectivity and updater binary

### scanner/ — Secret Detection Engine
- **Purpose**: Distributed scanner. Polls API for jobs, scans sources, detects secrets, reports findings.
- **Entrypoint**: `scanner/cmd/scanner/main.go`
- **Key packages**: `cli`, `detectors`, `sources`, `analyzers`, `components`, `notifiers`, `apiconn`, `healthcheck`, `config/feature`, `metrics`, `proxy`, `secrets`, `validate`, `workflows`
- **Core dependency**: `github.com/trufflesecurity/trufflehog/v3` (OSS engine)

### gateway/ — HTTP Gateway
- **Purpose**: Public-facing HTTP API. Routes requests, handles webhooks, caches, authenticates via Django.
- **Entrypoint**: `gateway/main.go`
- **Key packages**: `server`, `auth`, `cache`, `githubwebhook`, `async`, `issues`, `historical`, `idprolemapping`, `resources`, `api`
- **Router**: `github.com/go-chi/chi/v5`
- **Note**: Embeds compiled frontend assets
- **Health**: `/healthz` endpoint implemented in `gateway/api/v1/healthcheck/healthcheck.go`, tested in `healthcheck_test.go`, registered in `gateway/server/router.go` (exempt from auth middleware)
- **SAML**: Logging in `gateway/auth/saml/saml.go`; condition logs at verbosity v(2) to reduce noise

### web/ — Django Web Backend
- **Purpose**: Web UI backend, external customer API, auth, models.
- **Framework**: Django 4.2 + DRF 3.15
- **Language**: Python 3.11, managed by Poetry
- **Main app**: `webapi/`
- **URLs**: `/internal_api/v*` (frontend), `/api/v*` (external, OpenAPI), `/admin/`, `/healthz/`
- **Auth**: Session-based (UI), SAML/OAuth (SSO), magic links (django-sesame), API keys (external)
- **Key models**: `SecretV2`, `SecretV2Materialized`, `SecretLocation`, `SourceType`, `TriageState`
- **Key views**: `web/webapi/views/internal_api/` and `web/webapi/views/external_api/`
- **Filters**: `web/webapi/filters/` — custom DRF filters including `LowerCaseMultiValueCharFilter`, `MultiValueCharFilter`, `MultiValueCharFilterPgArray`
- **Migrations**: `web/webapi/migrations/` with `readme.md` documenting rationale
- **Test path inside container**: `/code/web/`

### frontend/ — React Frontend
- **Purpose**: Customer-facing web UI
- **Framework**: React 18 + TypeScript + Vite
- **Package manager**: Yarn 4.9.2
- **UI**: Chakra UI 2.8 + Emotion + react-select
- **Key deps**: react-router-dom, Formik+Yup, @tanstack/react-table, Recharts, Axios
- **Dev proxy**: `/internal_api` → Django (8000), `/v1_gateway` → Gateway (9000)
- **Filter logic**: Centralized in `frontend/src/services/helpers.ts`, `datafilters/`, `locationtypemappings.ts`
- **Filter interfaces**: `datafilters/common.ts`
- **Assets**: SVGs in `frontend/src/images/logos/`

### muskie/ — Database Test Infrastructure
- **Purpose**: Shared Postgres container manager, per-test database clones.
- **Key packages**:
  - `muskie/pkg/simmer` — Thread-safe, transaction-aware DB interface (wraps sql.DB, SQLBoiler compatible). Supports nested transactions via Postgres SAVEPOINTs.
  - `muskie/pkg/testdb` — Clone-per-test isolation: `testdb.WithDatabase(t, func(t, ctx, db) { ... })`
  - `muskie/cmd/devdb` — Dev database lifecycle (up/down/status/env)
  - `muskie/cmd/test` — Wrapper to run tests with managed Postgres

### thogctl/ — Deployment CLI
- **Purpose**: Deploy, manage, diagnose Thog installations on Kubernetes.
- **Entrypoint**: `thogctl/main.go`
- **Key packages**: `deploy`, `diagnose`, `ensure`, `gcp`, `kube`, `api`, `config`, `environments`, `secret`, `explain`, `slack_integration`
- **CLI framework**: `gopkg.in/alecthomas/kingpin.v2`
- **Health**: `/healthz` with DB + binary checks, robust K8s probe config

### e2e/ — End-to-End Tests
- **Framework**: Playwright + TypeScript
- **Test projects**: Base (port 20000), SAML (21000), OAuth (22000)
- **Run**: `pnpm run test:base` (dev), `pnpm test` (all, CI)

### fnord — AI CLI
- **Language**: Elixir (via optimus)
- **Purpose**: AI-driven code archaeology, playbook and doc tasks, entity management
- **Commands**: `fnord --help`, `fnord ask`, `fnord notes`

## Materialized View & Migration Patterns

### Key Matview
- `webapi_secrets_materialized` — aggregation logic managed by `define_new_mv` block
- Indexes use `gin_trgm_ops` on `distinct_location_*` fields for trigram search
- Index naming convention: `old_` prefix, `idx_` prefix for systematic management

### Migration Conventions
- Versioned, reversible migrations; Django is source of truth
- SQL operations via raw/procedural SQL and PL/pgSQL with intent-style comments
- "Indiana Jones switcheroo" technique: rename indexes → create temp new view → swap (minimizes downtime)
- Blue/green matview swap pattern
- Dropped `CONCURRENTLY` for high-contention index migrations to prevent 20+ minute timeouts
- Migration process is fully reversible; data migrations marked `elidable=true` for test skipping
- Explicit split between DDL/DML/backfill/removal migrations
- Model and migration removals occur in same branch when removing fields
- Migration rationale captured in both code comments and `web/webapi/migrations/readme.md`
- Scripts for migration reordering, squashing, dependency management
- Go models (sqlboiler) regenerated to match schema changes
- SQLite3 support fully removed (2025–2026); migrations/testing now PostgreSQL only

### Migration Commands
- `make migrate` — Run Django migrations
- `make web-migrations` / `make migrations` — Generate Django migrations (updates expected_migration_names.json)
- `make empty-migration` — Create empty migration
- `make models-local` — Generate Go models (sqlboiler)
- `make go-migration-files` — Export Django migrations to SQL for Go tests

## FE/BE Contracts & Normalization

### Filtering Contract
- **Backend**: Custom DRF filter classes (`LowerCaseMultiValueCharFilter`) normalize all input to lowercase, support null/empty, multi-value OR logic
- **Frontend**: `decodeFilterArray` and `decodeURIComponent` in FE helpers (replace "+" with space for safe decode)
- **Convention**: Lowercase normalization always performed at the caller, with strict FE/BE contract
- All filter state synced with URL params; filter/decode logic centralized and tested

### Search
- `_apply_search_term` pattern used across multiple API views (`notification.py`, `source.py`, `secret_v2.py`)
- Uses `TrigramSimilarity` from `django.contrib.postgres.search` for fuzzy matching
- Search fields: `name`, `fully_qualified_resource_name`, `distinct_location_*`, `secret_type`, `distinct_source_names_string`, `redacted`

## Health Check Architecture
- Standardized `/healthz` endpoint (consolidated from `/live` and `/ready`)
- Fully checks DB connectivity and binary existence
- Reports status codes for K8s probe integration
- K8s deployments use startup, liveness, and readiness probes pointed at `/healthz`
- Exempt from authentication middleware

## Configuration & Secrets Management
- Google Secret Manager for secrets
- ConfigCat for feature flags and config
- `scripts/configcat` — retrieves configcat key info and orphans
- Per-namespace deployment configuration
- Docs: `docs/config.md`, `docs/config.local.md`, `docs/config.thog-deployments.md`

## Test Database Architecture
- PostgreSQL 15 container started once per test run.
- All Django migrations applied to `test-db` database.
- `test-db` locked as template (`ALLOW_CONNECTIONS=false`).
- Each test gets a clone via `CREATE DATABASE ... TEMPLATE test-db`.
- Clones managed by factory (pre-warms pool) and janitor (async drop) goroutines.
- Entry point for tests: `testdb.WithDatabase(t, func(t, ctx, db) { ... })`

## Migration Export Pipeline
- `make go-migration-files` -> `api/scripts/export-migrations.sh`
- Starts temp PG container, runs Django `sqlmigrate` per migration, writes individual .sql files
- Files embedded via `//go:embed` in `api/test_migrations/embedded.go`
- Staleness test: `api/pkg/models_test/migrations_up_to_date_test.go` compares embedded files against `expected_migration_names.json`
- `expected_migration_names.json` auto-generated by `manage.py` during `make migrations`

## Build/Dev Commands

### Go
- `go vet ./path/to/pkg` — Verify syntax (preferred over `go build`)
- `go fmt ./path/to/file.go` — Format changed files only
- `go test -v ./path/to/pkg` — Run tests for specific package
- `go run ./muskie/cmd/test [flags]` — Run Go tests with shared Postgres container

### Make Targets
| Target | Purpose |
|--------|---------|
| `build-all` | Build gateway, scanner, API binaries |
| `build-{gateway,scanner,scanner-api}` | Build individual binaries |
| `rebuild-{gateway,scanner,scanner-api}` | Build + restart Docker container |
| `test-scanner` | Scanner unit tests (muskie test runner, 90s timeout) |
| `test-gateway` | Gateway unit tests (scripts/test-gateway.sh) |
| `test-api` | API unit tests (scripts/test-api.sh) |
| `test-muskie` | Muskie unit tests |
| `test-web` | Django tests (docker-compose + pytest) |
| `test-frontend` | Frontend tests (Node 20+corepack container) |
| `scanner-integration` | Scanner integration tests (40s timeout) |
| `scanner-integration-race` | Integration tests with race detection |
| `lint` | golangci-lint (15m timeout) |
| `vendor` | Update vendor directory |
| `mocks` | Generate mocks (mockgen) |
| `migrations` | Generate Django migrations (updates expected_migration_names.json) |
| `go-migration-files` | Export Django migrations to SQL for Go tests |
| `muskie-{up,down,status,env}` | Manage dev database lifecycle |
| `run-backend` | Start webapi container + deps |
| `run-frontend` | Start frontend dev server |

### Frontend
- `yarn install --ignore-engines` — Install deps
- `yarn test` — Run vitest
- `yarn tsc --noemit` — Type check
- `yarn coverage` — Coverage report
- `yarn ci-check` — Lint + prettier + test + TypeScript
- `corepack enable` — Required for Yarn 4.9.2 compatibility
- `npx playwright test` with `base_url` for live E2E

### Python
- `isort` and `black` enforced for code formatting
- `poetry run pytest` for running tests locally
- `docker compose run web pytest` for containerized tests
- `make web-shell` for interactive Django shell

## Testing Conventions

### Go Tests
- **Framework**: Standard `testing` package
- **Assertions**: `github.com/stretchr/testify/assert` + `require` (169+ test files)
- **Mocking**: `mockgen` (golang/mock v1.6.0+) via `//go:generate` directives
- **Test data**: `randomize.Struct()` for generation
- **gRPC testing**: `bufconn` for in-process testing without network (`api/pkg/integration`)
- **Build tags**: `//go:build integration` for integration tests (excluded from standard runs)
- **Total**: ~239 *_test.go files across the codebase

### Python Tests
- **Framework**: pytest 7.4 + pytest-django
- **Plugins**: pytest-xdist (parallel), pytest-env, pytest-timeout, pytest-socket (no network)
- **Test DB**: `thog_test` on local PostgreSQL port 5433
- **Test data**: Factory-based (`webapi.tests.factories`) for permissions, resources, secrets, sources
- **Helper**: `FeatureFlagOverrider` for managing feature flags during tests
- **Container test path**: Tests run inside `web` container at `/code/web/`

### Frontend Tests
- **Framework**: Vitest 3.2 + @testing-library/react
- **API mocking**: MSW (Mock Service Worker)
- **Environment**: jsdom

### E2E Tests
- **Framework**: Playwright
- **Projects**: Base, SAML, OAuth (isolated ports)
- **Live env testing**: Playwright runs against deployed envs, supports parallelism and debug capture

## Docker Compose (Local Dev)
- Platform: `linux/arm64`
- Services: `web`, `postgres` (15-alpine), `scanner`, `api`, `gateway`, `frontend-builder`, `pubsub-init`
- Web builds via `Dockerfile.web.localbuild`
- Scanner/API use `Dockerfile.api.debug` with Delve (`dlv`) for debugging
- Gateway uses `Dockerfile.gateway.dev` with Delve
- Postgres healthcheck: `pg_isready -U postgres`
- Web entrypoint: `/code/web/entry.sh`

## Conventions
- Django enums use `IntegerChoices`/`TextChoices` stored as column values, NOT FK-referenced lookup tables
- Go tests use `randomize.Struct()` for test data generation
- SQLBoiler for Go ORM code generation from DB schema
- `CGO_ENABLED=0` for static binaries, `-mod=vendor` for vendored deps
- Version injected via `-ldflags` at build time
- Delve debugger for Go services in local dev (ports 4000-4002)
- No hardcoded secrets; use Google Secret Manager or ConfigCat
- Structured, descriptive commit messages (scope, reason)
- Shell/Bats tests via `make lint` / `make test`
- Versioned, reversible migrations; generated model files not altered directly
- Dockerized parity for CI/CD; modular pipelines, one Workflow per subsystem
- Migrations as K8s init containers, PR reviewed before rollout
- Logging: JSON (zap/klog), health endpoints standard
- Shared `thog` service account
- Comments distinguish between rationale/intent and code behavior
- SQL migrations annotated with explicit rationale comments

## CI/CD
- **CI**: GitHub Actions (test-and-release, lint, integration tests)
- **Build**: Google Cloud Build (Docker images)
- **Runners**: Custom 16-CPU Linux x64
- **Test orchestration**: RWX Captain
- **GCP auth**: Workload Identity Federation
- **Dev deploy**: `scripts/deploy-dev.sh` via thogctl
- **Prod deploy**: Tagged releases (`vX.X.X`) via thogctl on `thog-deployments` repo
- **Dev branches**: Deployed to `pr-<number>.c1.dev.trufflehog.org`

## Secrets/Config
- GCP Secret Manager: `deploy` secret in both `thog-prod` and `thog-dev`
- Per-deployment: `config-env` secret derived from `deploy`
- Local dev: `.devsecrets/web.env`
- `make fetch-dev-secrets` to provision local secrets
