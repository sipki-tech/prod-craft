# Parallel Tests (Mandatory)

**Every test is parallel.** Call `t.Parallel()` in every `Test*` function and in every `t.Run` subtest. This is not a nice-to-have; it is the default that all other test design serves.

## The Rule
If a test *cannot* be made parallel, that is a **defect in the code under test, not a property of the test**. Fix the code until the test can be parallel.
- **Reason:** Parallel-safe code has no hidden shared state, no global mutation, no wall-clock dependence, and no unscoped external resources. Those are exactly the properties of good production code. A test that resists parallelism is pointing at a design smell — chase it down, don't paper over it with sequential execution.

```go
func TestThing(t *testing.T) {
    t.Parallel() // top level: parallel with sibling Test funcs

    for name, tc := range cases {
        name, tc := name, tc
        t.Run(name, func(t *testing.T) {
            t.Parallel() // parallel with sibling subtests
            // arrange / act / assert
        })
    }
}
```

## Ordering Inside a Test
1. `t.Cleanup(...)` registrations.
2. `t.Parallel()`.
3. Arrange → Act → Assert.

- **Reason:** Register cleanup before going parallel so teardown is attached regardless of scheduling. `t.Cleanup` (not `defer`) runs even after `t.FailNow` and composes across helpers like `start(t)`.

## When a Test "Can't" Be Parallel → Refactor the Code
| Blocker | Smell in the code | Fix so the test can be parallel |
|---|---|---|
| Global / package var mutated | Shared mutable state | Inject the dependency; pass it into the constructor |
| Reads `time.Now()` | Hidden wall-clock dependence | Inject a `Clock` (`style/time.md`); advance it in the test |
| Shared DB / Redis / bucket | Unscoped external resource | Namespace per `t.Name()` (`testing/integration.md`) |
| Real network call | Untestable coupling | `httptest.NewServer` / in-memory bufconn |
| Real filesystem path | Shared FS state | `t.TempDir()` (auto-cleaned, unique) |
| `os.Setenv` / reads env directly | Config read from process env | Load config once at the edge; pass typed config (`recipes/config.md`) |
| `init()` side effects / singletons | Order-dependent global setup | Construct explicitly in `start(t)` |

The pattern is always the same: **the dependency that blocks parallelism becomes a constructor parameter.** That is also what makes the production code correct under concurrency.

## The Narrow, Honest Exception
`t.Setenv` *forbids* `t.Parallel()` in the same test — by design. If you reach for `t.Setenv`, treat it as the signal that your code reads `os.Getenv` where it shouldn't. Move env reads to startup and inject typed config; then the test no longer needs `t.Setenv` and becomes parallel again.
- **Reason:** There is essentially no legitimate reason for *business* code to read process env at call time. Removing that need restores parallelism instead of excusing its absence.

## Loop-Variable Capture
Since Go 1.22 each iteration has its own loop variable, but keep the explicit `name, tc := name, tc` re-binding for clarity and to stay correct on older toolchains.
- **Reason:** Before 1.22, a parallel subtest closing over the loop variable read the *last* value — a classic flaky-test cause.

## `-race` Is Mandatory
Run unit tests with `-race -count=1`. Parallelism without the race detector hides the very bugs parallelism exposes.
- **Reason:** Parallel tests are how you *discover* data races; `-race` is how you *see* them. Never disable it. See `style/concurrency.md`.

```bash
gotestsum --format pkgname -- -race -count=1 ./...
```

## Don't Coordinate with `time.Sleep`
For eventual conditions use `require.Eventually(t, cond, 5*time.Second, 50*time.Millisecond)`; for ordering use channels/`sync`. Sleeps make parallel tests both slow and flaky (see `testing/integration.md`).
