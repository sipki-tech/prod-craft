# Generics

Type parameters (Go 1.18+) remove duplication for container and algorithm code. Use them where they reduce real duplication — not as a reflex.

## When to Use Generics
Reach for generics when you'd otherwise write the same logic for several types, or use `any` + type assertions / reflection.
- **Reason:** Generics give compile-time safety and zero reflection cost for collection helpers, result wrappers, and constraints over numeric types.

```go
// Good — one implementation for any comparable key
func Keys[K comparable, V any](m map[K]V) []K {
    out := make([]K, 0, len(m))
    for k := range m {
        out = append(out, k)
    }
    return out
}
```

## When NOT to Use Generics
If there's a single concrete type, or an interface already expresses the behavior, prefer the simpler option.
- **Reason:** Generics add cognitive load and can worsen readability. "A little copying is better than a little dependency" — and better than a contorted type parameter.

```go
// Prefer an interface when you need behavior, not a type container
func Process(r io.Reader) error // not Process[T io.Reader](r T) error
```

## Use the Standard Constraints and Packages
Use `cmp.Ordered`, the `slices` and `maps` packages, and `golang.org/x/exp/constraints` rather than redefining constraints.
- **Reason:** Standard building blocks interoperate and are well-tested.

```go
import "slices"

slices.Sort(xs)                     // any cmp.Ordered
i, ok := slices.BinarySearch(xs, x)
ys := slices.Clone(xs)
```

## Constrain Precisely
Use the narrowest constraint that compiles: `comparable` for map keys, `cmp.Ordered` for sorting, a custom interface constraint for required methods.
- **Reason:** A loose `any` constraint forces type switches inside the generic body, defeating the point.

```go
type Number interface {
    ~int | ~int64 | ~float64
}

func Sum[T Number](xs []T) T {
    var total T
    for _, x := range xs {
        total += x
    }
    return total
}
```

## Don't Build a Framework
Avoid deep generic abstractions (generic "repository" base types, option monads). Keep type parameters at the leaf utility level.
- **Reason:** Over-generic core types become unreadable and hard to evolve; clean architecture favors explicit contracts (see `architecture/clean.md`).

## Type Inference at Call Sites
Let the compiler infer type arguments; only specify them when inference fails.

```go
Sum([]int{1, 2, 3})        // inferred
Keys[string, int](myMap)   // explicit only when needed
```
