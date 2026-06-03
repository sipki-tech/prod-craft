# Fixtures & Golden Files

Keep test inputs and expected outputs out of the test body. Use package-level fixtures for shared values, `testdata/` for files, and golden files for large expected outputs.

## Package-Level Fixtures
Declare shared, immutable test values once in `init_test.go`.
- **Reason:** Avoids duplicating magic values across cases and makes intent obvious. Keep them immutable — a fixture mutated by one parallel test corrupts another (see `testing/parallel.md`).

```go
// init_test.go
var (
    errAny  = errors.New("any error")
    origin  = app.Origin{IP: net.ParseIP("192.100.10.4"), UserAgent: "UA"}
    ownerID = uuid.Must(uuid.NewV4())
    fileID  = uuid.Must(uuid.NewV4())
)
```

## `testdata/` for File Inputs
Store sample files (images, JSON payloads, SQL) in a `testdata/` directory next to the test.
- **Reason:** The Go toolchain ignores any directory named `testdata`, so these files never end up in builds, and the path is stable.

```go
const pngFilePath = "./testdata/test.png"

f, err := os.Open(pngFilePath)
require.NoError(t, err)
t.Cleanup(func() { _ = f.Close() })
```

## `t.TempDir()` for Ephemeral Output
When a test writes files, write them under `t.TempDir()`.
- **Reason:** It returns a unique directory per test and auto-removes it in cleanup, so tests stay parallel-safe and leave no residue.

## Golden Files for Large Expected Output
For rendered templates, serialized structures, or formatted reports, compare against a committed `.golden` file regenerated with an `-update` flag.
- **Reason:** Embedding a 200-line expected string in the test is unreadable; a golden file diffs cleanly in review.

```go
var update = flag.Bool("update", false, "update golden files")

func TestRender(t *testing.T) {
    t.Parallel()

    got := render(input)
    golden := filepath.Join("testdata", t.Name()+".golden")

    if *update {
        require.NoError(t, os.WriteFile(golden, got, 0o644))
    }
    want, err := os.ReadFile(golden)
    require.NoError(t, err)
    require.Equal(t, string(want), string(got))
}
```

Regenerate with `go test ./... -update`, then **review the diff** before committing.
- **Reason:** `-update` blindly accepts current output; an unreviewed update can bake in a regression.

## Build Fixtures with Helpers, Not Copy-Paste
For complex inputs, use small builder helpers (`newTestUser(opts...)`) registered with `t.Helper()`.
- **Reason:** Helpers keep cases focused on what differs; `t.Helper()` makes failure line numbers point at the caller.
