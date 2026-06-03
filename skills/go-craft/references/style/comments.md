# Comments & Documentation

Comments document intent and contracts, not mechanics. Write them for the reader of the godoc, not as a narration of the code.

## Doc Comments Start with the Identifier
Every exported identifier has a doc comment that begins with its name and is a complete sentence.
- **Reason:** `go doc`, `pkg.go.dev`, and editors render these. Starting with the name produces readable, greppable docs.

```go
// Good
// UserByID returns the user with the given id.
// Errors: ErrNotFound, unknown.
func (a *App) UserByID(ctx context.Context, id uuid.UUID) (*User, error)

// Bad
// this gets a user
func (a *App) UserByID(...) (*User, error)
```

## Package Comments
Every package has a `// Package <name> ...` comment, on the package clause of one file (often `doc.go`).
- **Reason:** It's the package's landing description in godoc.

```go
// Package app holds the business logic and the contracts its adapters implement.
package app
```

## Document the Error Contract on Interfaces
Interface methods list their sentinel errors with `// Errors: ErrX, ErrY, unknown.` (see `style/errors.md` and `style/interfaces.md`).
- **Reason:** The error contract is part of the API; callers route on it.

## Comment the "Why", Not the "What"
Explain non-obvious decisions, invariants, and trade-offs. Don't restate the code.
- **Reason:** The code already says what it does. Comments earn their keep by capturing context the code can't.

```go
// Good — explains a non-obvious choice
// Serializable isolation: this read-then-write must not interleave with a concurrent upgrade.
tx, err := r.db.BeginTxx(ctx, &sql.TxOptions{Isolation: sql.LevelSerializable})

// Bad — narrates the obvious
// begin a transaction
tx, err := r.db.BeginTxx(ctx, nil)
```

## No Commented-Out Code
Delete dead code; version control remembers it. Don't leave `// old := ...` blocks.
- **Reason:** Commented code rots, confuses readers, and is invisible to refactoring tools.

## Mark Generated Files
Generated files carry `// Code generated ... DO NOT EDIT.` as their first line.
- **Reason:** Tools (and `golangci-lint` exclusions) detect this marker; humans know not to hand-edit.

## `TODO`/`FIXME` Carry an Owner or Issue
`// TODO(username): ...` or `// TODO(#123): ...`, never a bare `// TODO`.
- **Reason:** An attributed TODO is actionable; an anonymous one is litter.
