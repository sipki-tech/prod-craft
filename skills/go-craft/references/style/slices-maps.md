# Slices & Maps

Slices and maps are reference-like and full of sharp edges around nil, capacity, and aliasing.

## Preallocate When the Size Is Known
Use `make([]T, 0, n)` when you know roughly how many elements you'll append.
- **Reason:** Avoids repeated reallocation/copying as the slice grows. `prealloc` flags missed cases.

```go
// Good
out := make([]User, 0, len(rows))
for _, r := range rows {
    out = append(out, r.toDomain())
}

// Bad
var out []User // reallocates as it grows
```

## `nil` Slice vs Empty Slice
A `nil` slice and an empty slice behave the same for `len`, `range`, and `append`. Return `nil` for "no results"; reserve an explicit `[]T{}` only when an encoder must emit `[]` not `null`.
- **Reason:** Idiomatic Go treats nil slices as empty; forcing `[]T{}` everywhere is noise.

```go
func list() []User {
    if none {
        return nil // fine: callers range over it safely
    }
    ...
}
```

## Check Map Presence with the Comma-Ok Idiom
Distinguish "absent" from "present with zero value".
- **Reason:** `m[k]` alone returns the zero value for missing keys, hiding absence.

```go
v, ok := m[key]
if !ok {
    return ErrNotFound
}
```

## Maps Are Not Safe for Concurrent Use
Guard a shared map with a `sync.Mutex` (or use `sync.Map` for specific patterns). The `-race` detector will catch violations.
- **Reason:** Concurrent map read/write panics or corrupts memory. See `style/concurrency.md`.

## Beware Slice Aliasing and `append`
A sub-slice shares the backing array; `append` may mutate the original or not, depending on capacity. Copy when you need independence.
- **Reason:** Aliasing bugs are silent and data-dependent.

```go
// Independent copy
dst := make([]T, len(src))
copy(dst, src)

// Cut capacity to force a fresh array on next append (three-index slice)
safe := original[low:high:high]
```

## Don't Retain Large Backing Arrays
Slicing a huge buffer keeps the whole array alive. Copy the small piece you need.
- **Reason:** A 1KB sub-slice of a 10MB buffer pins all 10MB from GC.

## Iterate Maps Without Relying on Order
Map iteration order is randomized. Sort keys when you need determinism (output, golden files).

```go
keys := make([]string, 0, len(m))
for k := range m {
    keys = append(keys, k)
}
slices.Sort(keys)
```

## Standard-Library Generics First
Prefer `slices` and `maps` (and, judiciously, `samber/lo`) over hand-rolled loops for `Sort`, `Contains`, `IndexFunc`, `Keys`, `Clone`.
- **Reason:** Less code, fewer off-by-one bugs. See `style/generics.md`.
