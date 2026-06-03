# Testing in Go

Go has a robust built-in testing framework, augmented by community libraries for assertions and integration tests. This file is the overview; for task-focused depth see `../testing/unit.md`, `../testing/parallel.md` (the mandatory-parallel rule), `../testing/mocking.md` (gomock + `start(t)`), `../testing/integration.md`, and `../testing/fixtures-golden.md`.

## File and Package Naming
Place tests in `file_test.go` adjacent to the file being tested. Use a `_test` package suffix (e.g., `package app_test`) for black-box testing.
- **Reason:** Using a `_test` package forces you to test the public API, ensuring you don't couple tests to internal state.

```go
// cmd/app/internal/app/handlers_test.go
package app_test

import "testing"
```

## Test Initialization with `start(t)` Helper
Create an `init_test.go` file with a `start(t *testing.T)` function that bootstraps all mocks, creates the `App` under test, and returns everything the test needs.
- **Reason:** Eliminates repetitive setup boilerplate across tests. Every test starts from a consistent, clean state.

```go
// init_test.go
package app_test

type mocks struct {
    hasher   *MockPasswordHash
    repo     *MockRepo
    sessions *MockSessions
    file     *MockFileStore
    auth     *MockAuth
    id       *MockID
    email    *MockEmailSender
}

func start(t *testing.T) (context.Context, *app.App, *mocks, *require.Assertions) {
    t.Helper()
    ctrl := gomock.NewController(t)

    mockRepo := NewMockRepo(ctrl)
    mockHasher := NewMockPasswordHash(ctrl)
    // ... other mocks ...

    module := app.New(mockRepo, mockHasher, mockAuth, mockID, mockSession, mockFileStore, ...)

    m := &mocks{
        repo:     mockRepo,
        hasher:   mockHasher,
        // ...
    }

    return testhelper.Context(t), module, m, require.New(t)
}
```

## Package-Level Test Fixtures
Declare common test values as package-level variables in `init_test.go`.
- **Reason:** Avoids duplicating magic values across tests and makes test intent clearer.

```go
var (
    errAny  = errors.New("any error")
    origin  = app.Origin{IP: net.ParseIP("192.100.10.4"), UserAgent: "UserAgent"}
    ownerID = uuid.Must(uuid.NewV4())
    fileID  = uuid.Must(uuid.NewV4())
)
```

## Mock Generation with `mockgen`
Use `go.uber.org/mock/mockgen` with `//go:generate` in a dedicated `generate_test.go` file.
- **Reason:** Generated mocks go into the `_test` package — they are never compiled into production code.

```go
// generate_test.go
package app_test

//go:generate mockgen -source=contracts.go -destination mock.app.contracts_test.go -package app_test
```

## Table-Driven Tests
Use table-driven tests for testing multiple scenarios of the same function.
- **Reason:** Reduces boilerplate and makes it easy to add new test cases.

```go
func TestAdd(t *testing.T) {
    tests := []struct {
        name     string
        a, b     int
        expected int
    }{
        {"positive", 2, 2, 4},
        {"negative", -1, 1, 0},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := Add(tt.a, tt.b)
            require.Equal(t, tt.expected, result)
        })
    }
}
```

## `assert` vs `require` (testify)
Use `github.com/stretchr/testify`. Use `require` when a failure means subsequent assertions will panic. Use `assert` when you want to see all failures in a single run.
- **Reason:** `require.NoError` stops the test immediately. `assert.NoError` logs and continues, leading to nil pointer panics.

```go
// Good
user, err := FetchUser(1)
require.NoError(t, err) // Stops test here if err != nil
assert.Equal(t, "Alice", user.Name)

// Bad
user, err := FetchUser(1)
assert.NoError(t, err)
assert.Equal(t, "Alice", user.Name) // PANIC if user is nil!
```

## Integration Tests with `testcontainers-go`
Use `testcontainers-go` to spin up real Docker containers (Postgres, Redis, MinIO). Tag integration tests with `//go:build integration`.
- **Reason:** Real containers give highest confidence. The build tag prevents them from running during fast unit test cycles.

```go
//go:build integration

func TestIntegration(t *testing.T) {
    ctx := testhelper.Context(t)
    // testhelper.Start(t) spins up containers
    // ...
}
```

## HTTP Testing with `httptest`
Use `net/http/httptest` to test HTTP handlers without binding to a real port.

```go
req := httptest.NewRequest(http.MethodGet, "/users/1", nil)
w := httptest.NewRecorder()
handler.ServeHTTP(w, req)
require.Equal(t, http.StatusOK, w.Code)
```

## Running Tests
Always run tests with the race detector. Use `gotestsum` for better output formatting.
```bash
gotestsum --format pkgname -- -race -cover -count=1 ./...
```

## Task Runner Commands
Standardize test commands via `Taskfile.yml`:
```yaml
tasks:
  test-unit:
    cmds:
      - "gotestsum --format pkgname -- -coverprofile=cover.out -race -count=1 ./..."
  test-integration:
    cmds:
      - "gotestsum --format pkgname -- -tags=integration -race -count=1 ./..."
```
