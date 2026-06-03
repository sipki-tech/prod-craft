# Unit Testing

Unit tests run in-process with no real I/O. They are fast, parallel (see `testing/parallel.md`), and table-driven.

## Black-Box `_test` Package
Put tests in `package <pkg>_test`, testing only the exported API. Use `export_test.go` to expose internals when genuinely needed.
- **Reason:** Testing the public surface keeps tests decoupled from implementation details, so refactors don't break tests that should still pass.

```go
// handlers_test.go
package app_test
```

## Table-Driven with Named Cases
Drive scenarios from a `map[string]struct{...}` (the key is the case name) or a slice of structs with a `name` field. One `t.Run` per case.
- **Reason:** Adding a case is one line; the case name appears in `gotestsum` output and `-run` filters. A map also randomizes order, surfacing hidden inter-case coupling.

```go
func TestApp_VerificationEmail(t *testing.T) {
    t.Parallel()

    testCases := map[string]struct {
        repoErr error
        want    error
    }{
        "free":           {repoErr: app.ErrNotFound, want: nil},
        "email_taken":    {repoErr: nil, want: app.ErrEmailExist},
        "repo_internal":  {repoErr: errAny, want: errAny},
    }

    for name, tc := range testCases {
        name, tc := name, tc
        t.Run(name, func(t *testing.T) {
            t.Parallel()

            ctx, module, mocks, assert := start(t) // see testing/mocking.md
            mocks.repo.EXPECT().UserByEmail(ctx, "e@x.com").Return(nil, tc.repoErr)

            err := module.VerificationEmail(ctx, "e@x.com")
            assert.ErrorIs(err, tc.want)
        })
    }
}
```

## Arrange / Act / Assert
Structure each case as three visual blocks: build inputs and expectations, call the function once, assert the outcome.
- **Reason:** A predictable shape makes tests skimmable and keeps a single behavior per case.

## `require` vs `assert`
Use `require` (or a bound `assert := require.New(t)`) for invariants whose failure makes the rest of the case meaningless; use `assert` when you want to keep checking after a failure.
- **Reason:** `require.NoError` stops the case immediately; continuing past a failed `NoError` typically nil-panics. The `start(t)` helper conventionally returns a `*require.Assertions`.

```go
u, err := FetchUser(ctx, id)
require.NoError(t, err)      // stop here on failure
require.Equal(t, "Alice", u.Name)
```

## Assert Errors by Identity, Not String
Use `require.ErrorIs(t, err, want)` / `errors.As`, never `err.Error() == "..."`.
- **Reason:** Message text is not part of the contract; sentinels are (see `style/errors.md`).

## Edge-Case Checklist
For any pure function, cover: empty input, single element, max size, unicode, leading/trailing whitespace, the error path, and boundary values.
- **Reason:** Bugs cluster at boundaries; a checklist makes coverage deliberate rather than incidental.

## Keep Units Small
If a test needs five mocks, the function under test is doing too much — extract a smaller unit (see `style/functions.md`). Mock only at boundaries; never mock the function's own helpers (see `testing/mocking.md`).

## No Real Time, Network, or Filesystem
Inject a `Clock` (`style/time.md`), use `httptest`/bufconn, and `t.TempDir()`. If a test genuinely needs real infra, it is an integration test — see `testing/integration.md`.
