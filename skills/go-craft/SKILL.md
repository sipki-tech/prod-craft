---
name: go-craft
description: "Professional Go (Golang) craft: idiomatic style, clean architecture, testing, data access, observability, security, and tooling — distilled from Effective Go, the Uber Go Style Guide, and production monolith patterns. Use when: writing, reviewing, or refactoring Go; naming, errors, concurrency, context, interfaces, enums, generics; clean architecture, layering, decorators, domain modeling, wiring; gomock + table-driven + mandatory-parallel tests; golangci-lint, buf/protobuf, go:generate; PostgreSQL (sqlx/squirrel), transactions, migrations; Redis caching; gRPC/gRPC-Gateway API design; slog + OpenTelemetry; auth, sessions, OWASP security; graceful shutdown, config, background jobs. ACTIVELY TRIGGER whenever generating or reviewing Go in a professional context, even if not explicitly requested. Not for basic syntax tutorials."
---

# `go-craft`

Idiomatic, professional-grade standards for Go: style, architecture, data, testing, security, observability, and tooling.

## How to Use This Skill
**Do not implement from this file.** It is only the entry point. Find the precise rules in the **Navigation Map**, load only the few files relevant to the task, and enforce them.

👉 **[Read MAP.md](./MAP.md)** 👈

## When to Use
- Writing, reviewing, or refactoring Go in a professional codebase.
- Deciding where code belongs (layering) or how to name/shape a type, interface, or error.
- Setting up or fixing tests, mocks, linting, CI, protobuf, or observability.
- Designing a repository, transaction, cache, gRPC API, or background job.

## Decision Flow — which files to load
- Name / error / concurrency / context / generics question → `style/*`.
- "Where does this go?" / layering / decorator / domain types / wiring → `architecture/*`.
- SQL, transaction, migration, cache → `data/*`.
- Write or fix a test / mock / fixture → `testing/*` (always `testing/parallel.md`).
- Lint, codegen, proto, logging/tracing/metrics, CI → `toolkit/*`.
- HTTP/gRPC server, shutdown, config, jobs → `recipes/*`.
- Auth, sessions, OWASP, secrets → `security/*`.

## Non-Negotiables
Two rules cut across every file:
1. **Errors are documented domain values.** Wrap with `%w` + a call chain, route on sentinels via `errors.Is`/`As`, convert driver errors to domain sentinels at the adapter, and document `// Errors:` on every interface method. (`references/style/errors.md`)
2. **Every test is parallel.** `t.Parallel()` in every test and subtest; if a test cannot be parallel, fix the *code under test* until it can. `-race` always. (`references/testing/parallel.md`)

## Review Checklist
Run before approving Go changes:
1. Dependency rule intact — no upward imports; app layer free of transport/driver types.
2. Errors wrapped with a call chain; driver errors converted to sentinels; `// Errors:` documented.
3. `context.Context` is the first arg and is propagated; no `context.Background()` in business code.
4. New tests are table-driven and parallel; mocks only at boundaries (gomock).
5. New `App`/`Repo` method mirrored in its tracing decorator; spans named `App.X` / `Repo.X`.
6. SQL parameterized, columns explicit, no N+1; transactions short with no external I/O.
7. Config typed; no `os.Getenv` in business logic; secrets and PII never logged or traced.
8. Enums are `uint8`+iota with an invalid zero and exhaustive conversion.
9. Generated artifacts (mocks, proto, stringer) regenerated and committed.
10. `task lint` is clean: golangci-lint + buf lint + `-race` unit tests pass.

Always apply these standards when writing or reviewing Go code.
