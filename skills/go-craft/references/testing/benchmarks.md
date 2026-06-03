# Benchmarks & Profiling

Optimize with data, not vibes. Measure first, change one thing, measure again. Go's toolchain has first-class benchmarking and profiling — use it before hand-optimizing.

## Write a Benchmark
A benchmark lives in a `_test.go` file, starts with `Benchmark`, and runs the code under test `b.N` times. Report allocations.
```go
func BenchmarkEncode(b *testing.B) {
    in := makeInput()
    b.ReportAllocs()
    b.ResetTimer() // exclude the setup above from timing
    for range b.N {
        _ = Encode(in)
    }
}
```
On Go 1.24+, prefer `b.Loop()` — it keeps the loop body from being optimized away and scopes the timer correctly:
```go
func BenchmarkEncode(b *testing.B) {
    in := makeInput()
    b.ReportAllocs()
    for b.Loop() {
        _ = Encode(in)
    }
}
```

## Run and Read
```bash
go test -run=^$ -bench=BenchmarkEncode -benchmem -count=10 ./...
```
- **`-run=^$`** disables normal tests so only benchmarks run.
- **`-benchmem`** adds `B/op` (bytes per op) and `allocs/op` — often more actionable than `ns/op`.
- **`-count=10`** repeats for statistical stability.

Fewer allocations usually beats micro-tuning CPU.

## Compare with `benchstat`
Don't eyeball two runs — noise dominates. Capture before/after and compare:
```bash
go test -bench=. -benchmem -count=10 ./... > old.txt
# ... make the change ...
go test -bench=. -benchmem -count=10 ./... > new.txt
benchstat old.txt new.txt
```
`benchstat` reports the delta with a p-value; a change without statistical significance isn't a win.

## Avoid the Dead-Code Trap
The compiler may delete work whose result is unused. With a `b.N` loop, assign to a package-level sink (or otherwise consume the result). `b.Loop()` avoids this by construction.
```go
var sink []byte

func BenchmarkEncode(b *testing.B) {
    var out []byte
    for range b.N {
        out = Encode(in)
    }
    sink = out
}
```

## Profile the Hot Path (`pprof`)
Capture a profile from a benchmark or a running server, then inspect it:
```bash
go test -bench=. -cpuprofile=cpu.out -memprofile=mem.out ./pkg/...
go tool pprof -http=:0 cpu.out   # interactive flame graph in the browser
```
Profile types: **CPU** (where time goes), **heap** (allocations), **block** (goroutines blocked on sync), **mutex** (lock contention). For live services, expose `net/http/pprof` on the **internal** port only — never public (see [`../security/security.md`](../security/security.md)); for continuous profiling see [`../toolkit/observability.md`](../toolkit/observability.md) (Pyroscope).

## Reduce Allocations
- **Preallocate** slices/maps with known capacity (`make([]T, 0, n)`) — see [`../style/slices-maps.md`](../style/slices-maps.md).
- **Reuse buffers** with `sync.Pool` for short-lived, frequently-allocated objects on a hot path. Don't pool everything — it adds complexity and can hurt for large or long-lived objects.
- **Avoid hidden copies** (large struct value receivers, `[]byte`↔`string` conversions in loops).

```go
var bufPool = sync.Pool{New: func() any { return new(bytes.Buffer) }}

func render() string {
    b := bufPool.Get().(*bytes.Buffer)
    b.Reset()
    defer bufPool.Put(b)
    // ... use b ...
    return b.String()
}
```

## Escape Analysis
A value that "escapes" to the heap costs an allocation. Ask the compiler why:
```bash
go build -gcflags='-m' ./pkg/... 2>&1 | grep escapes
```
Common causes: returning a pointer to a local, storing a value in an interface, capturing it in a closure that outlives the call. Don't chase this without a benchmark showing it matters.

## Don't Optimize Blind
- **Measure first:** a profile shows the 5% of code that costs 95% of the time. Optimizing elsewhere is wasted effort and added complexity.
- **Keep the benchmark:** commit it next to the code so regressions stay visible.
- **Readability wins ties:** if two versions benchmark the same, keep the clearer one.

## Checklist
- [ ] Benchmark reports allocations (`b.ReportAllocs` / `-benchmem`).
- [ ] Setup excluded from timing (`b.ResetTimer` or `b.Loop`).
- [ ] Results compared with `benchstat` over `-count≥10`, not eyeballed.
- [ ] Result consumed (sink) so the compiler can't delete the work.
- [ ] Profiled the hot path before optimizing; `pprof` exposed only internally.
- [ ] Allocation cuts (prealloc, `sync.Pool`) backed by before/after numbers.
