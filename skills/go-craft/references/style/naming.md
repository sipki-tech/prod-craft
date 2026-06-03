# Go Naming Conventions

Consistent naming makes Go code readable and predictable. Follow these rules derived from Effective Go and the Uber Go Style Guide.

## Package Names
Keep package names short, concise, and lowercase. Avoid `_` or `mixedCaps`. The package name should be a noun.
- **Reason:** Package names are used as prefixes to their contents (e.g., `bytes.Buffer`). Short names avoid stutter.

```go
// Good
package time
package list
package httputil

// Bad
package util // Too generic
package common // Meaningless
package user_service // Uses underscores
```

## Variable Names
Prefer short names, especially for local variables with limited scope. The larger the scope, the longer and more descriptive the name can be.
- **Reason:** Go prioritizes readability through context. Short names reduce visual clutter.

```go
// Good
func fetch(c *http.Client) { ... }
var count int

// Bad
func fetch(httpClient *http.Client) { ... }
var numberOfItems int
```

## Initialisms and Acronyms
Keep acronyms consistently cased. If it's `URL`, use `URL` or `url`, never `Url`.
- **Reason:** Mixed casing makes code look inconsistent and causes typos.

```go
// Good
var serverURL string
var userID int
type HTTPClient struct{}

// Bad
var serverUrl string
var userId int
type HttpClient struct{}
```

## Interface Names
Single-method interfaces must be named by the method name plus an `-er` suffix or similar modification.
- **Reason:** This is an established standard in the standard library (`io.Reader`, `io.Writer`, `fmt.Stringer`).

```go
// Good
type Reader interface {
    Read(p []byte) (n int, err error)
}

// Bad
type ReadInterface interface {
    Read(p []byte) (n int, err error)
}
```

## Receiver Names
Use a 1-letter or 2-letter abbreviation of the type's name for receivers. Be consistent across all methods of that type.
- **Reason:** `this`, `self`, or `me` are not idiomatic in Go.

```go
// Good
func (c *Client) Fetch() error { ... }

// Bad
func (self *Client) Fetch() error { ... }
func (client *Client) Fetch() error { ... }
```

## Constant Naming
Use `mixedCaps` for constants, just like regular variables. Do NOT use `SCREAMING_SNAKE_CASE`.
- **Reason:** Go uses capitalization strictly for visibility (exported vs unexported).

```go
// Good
const defaultTimeout = 5 * time.Second
const MaxRetries = 3

// Bad
const DEFAULT_TIMEOUT = 5 * time.Second
const MAX_RETRIES = 3
```

## Avoid Stutter
Don't repeat the package name in its exported identifiers. The package qualifier already supplies context.
- **Reason:** `http.HTTPServer` reads as a stutter at the call site; `http.Server` is correct.

```go
// Good
package user
func New() *Service {} // call site: user.New()

// Bad
package user
func NewUserService() *UserService {} // call site: user.NewUserService()
```

## Getters Without `Get`
Omit `Get` from getter names; keep `Set` for setters.
- **Reason:** Idiomatic Go reads `u.Name()`, not `u.GetName()`.

```go
// Good
func (u *User) Name() string { return u.name }

// Bad
func (u *User) GetName() string { return u.name }
```
