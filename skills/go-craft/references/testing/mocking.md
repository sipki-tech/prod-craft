# Mocking with gomock

Use **`go.uber.org/mock`** (the maintained gomock fork) with `mockgen`. Mock only the interfaces at your layer's boundary; never mock the code under test's own helpers.

## Tooling
- Library: `go.uber.org/mock/gomock`.
- Generator: `go.uber.org/mock/mockgen`.
- **Reason:** gomock gives call-count assertions, argument matchers, and ordered expectations from your `app/contracts.go` interfaces, generated and committed alongside tests.

## Generate via `//go:generate`
Put the directive in a dedicated `generate_test.go` so mocks land in the `_test` package and never compile into production binaries.

```go
// generate_test.go
package app_test

//go:generate mockgen -source=contracts.go -destination mock.app.contracts_test.go -package app_test
```

Regenerate with `go generate ./...` (or `task generate`) after changing a contract. Never hand-edit generated mocks.

## Bundle Mocks in a `mocks` Struct + `start(t)` Helper
Build all mocks, construct the system under test, and return everything from one `start(t)` helper.
- **Reason:** Eliminates per-test setup boilerplate and gives every test an identical, clean starting point. `gomock.NewController(t)` auto-verifies expectations via `t.Cleanup` — no manual `Finish()`.

```go
// init_test.go
package app_test

type mocks struct {
    repo     *MockRepo
    hasher   *MockPasswordHash
    sessions *MockSessions
    auth     *MockAuth
    email    *MockEmailSender
}

func start(t *testing.T) (context.Context, *app.App, *mocks, *require.Assertions) {
    t.Helper()
    ctrl := gomock.NewController(t) // auto-Finish on cleanup

    m := &mocks{
        repo:     NewMockRepo(ctrl),
        hasher:   NewMockPasswordHash(ctrl),
        sessions: NewMockSessions(ctrl),
        auth:     NewMockAuth(ctrl),
        email:    NewMockEmailSender(ctrl),
    }
    module := app.New(m.repo, m.hasher, m.auth, m.sessions, m.email)

    return testhelper.Context(t), module, m, require.New(t)
}
```

## Setting Expectations
`EXPECT()` declares a call, its argument matchers, and its return. By default each is expected exactly once.

```go
mocks.repo.EXPECT().UserByEmail(ctx, "e@x.com").Return(nil, app.ErrNotFound)
mocks.hasher.EXPECT().Hashing(gomock.Any(), "pass").Return([]byte("hash"), nil)
mocks.email.EXPECT().Send(gomock.Any(), gomock.Any()).Times(0) // assert NOT called
```

Common matchers: `gomock.Any()`, `gomock.Eq(x)`, `gomock.Nil()`, `gomock.Len(n)`, `gomock.Cond(func(x any) bool {...})`.

## `DoAndReturn` for Closures (e.g. `Tx`)
When the method takes a callback (the `Tx` pattern from `architecture/transactions.md`), use `DoAndReturn` to actually invoke the callback with the mock itself.
- **Reason:** This exercises the real closure body against your mocked repo, so the transactional steps are tested — not skipped.

```go
mocks.repo.EXPECT().Tx(ctx, gomock.Any()).
    DoAndReturn(func(ctx context.Context, fn func(app.Repo) error) error {
        return fn(mocks.repo) // run the closure against the same mock
    })
mocks.repo.EXPECT().UserSave(ctx, gomock.Any()).Return(wantID, nil)
```

## Ordering and Counts
Use `gomock.InOrder(...)` for required sequences and `.Times(n)` / `.MinTimes` / `.MaxTimes` / `.AnyTimes()` for counts.

```go
gomock.InOrder(
    mocks.repo.EXPECT().UserSave(ctx, gomock.Any()).Return(id, nil),
    mocks.repo.EXPECT().SaveTask(ctx, gomock.Any()).Return(taskID, nil),
)
```

## Mock at Boundaries Only
Mock `Repo`, `FileStore`, `Sessions`, `PasswordHash`, `EmailSender` — the interfaces the app declares (`style/interfaces.md`). Do **not** mock the function's own internal helpers.
- **Reason:** Mocking internals tests the mock, not the behavior, and locks tests to implementation.

## gomock vs Hand-Written Fakes
| Use gomock when | Use a hand fake when |
|---|---|
| You assert call counts / argument shapes | A tiny in-memory impl is enough |
| The interface has many methods you stub per-test | The contract is behavior, not call shape |
| The boundary interface changes rarely | The interface is ≤ 3 methods |

- **Reason:** gomock shines for verifying interactions; a fake shines when you only need a working stand-in (e.g. an in-memory repo for a flow test).
