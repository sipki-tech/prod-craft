# Linting with golangci-lint

`golangci-lint` is the standard, fast, and highly configurable linter runner for Go.

## Installation
```bash
brew install golangci-lint
```

## Discovering & Inspecting Linters
You don't have to memorize the catalog — ask the tool and the docs.
- **Full catalog** (descriptions, which are enabled by default, which support autofix): <https://golangci-lint.run/usage/linters/>.
- **What's available and what's active in *your* config:**
```bash
golangci-lint linters        # enabled vs disabled under the current config
golangci-lint help linters   # every linter with a one-line description
```
- **Validate and locate your config:**
```bash
golangci-lint config verify  # check the config against the schema
golangci-lint config path    # print which config file is in effect
```
- **Upgrade v1 → v2 config:** `golangci-lint migrate` rewrites an old `.golangci.yml` into the v2 format.

Run `golangci-lint linters` after every `enable`/`disable` change to confirm the active set is what you expect.

## Recommended Configuration (golangci-lint v2)
Use `version: "2"` config format. Start with **all linters enabled** and selectively disable the ones that are too noisy for your team.
- **Reason:** Starting from `default: all` ensures you get maximum coverage by default. You only opt out of what you explicitly reject.

```yaml
version: "2"
run:
  tests: false
linters:
  default: all
  disable:
    - exhaustruct   # Too verbose for most projects
    - lll           # Line length — handled by formatter
    - nonamedreturns # Named returns are useful in some cases
    - varnamelen    # Short variable names are idiomatic Go
    - wsl           # Whitespace style — too opinionated
```

## Tag Casing Rules
Enforce `snake_case` for all struct tags (JSON, YAML, XML, BSON, etc.) using the `tagliatelle` linter.
- **Reason:** Consistent tag casing across the entire codebase prevents API contract mismatches.

```yaml
  settings:
    tagliatelle:
      case:
        use-field-name: false
        rules:
          json: snake
          yaml: snake
          xml: snake
          bson: snake
```

## Import Guard (`depguard`)
Restrict which packages can be imported in different parts of the codebase.
- **Reason:** Prevents accidental dependencies. For example, test files should only import `$gostd` and `testify`, nothing else.

```yaml
    depguard:
      rules:
        cmd:
          files: ["cmd/*/*.go"]
          allow: [$gostd]
        tests:
          files: [$test]
          allow:
            - $gostd
            - github.com/stretchr/testify
```

## Exclusion Rules
Suppress known false positives and noisy warnings for specific paths or patterns.
- **Reason:** Tests have different quality standards (e.g., `dupl`, `funlen`, `gosec` are acceptable in test code).

```yaml
  exclusions:
    generated: lax
    presets:
      - comments
      - common-false-positives
    rules:
      - linters: [ireturn]
        text: returns generic interface
      - linters: [gocritic]
        path: cmd/[^/]+/.+\.go
        text: exitAfterDefer
      - linters: [dupl, errcheck, funlen, gochecknoglobals, gosec, unparam]
        path: _test\.go
    paths:
      - bin
      - scripts
      - third_party$
```

## Formatters
Enable `gci`, `gofmt`, `gofumpt`, and `goimports` as formatters. Configure `gci` to group imports into three blocks: standard library, third-party, and project-local.
- **Reason:** Consistent import ordering prevents noisy diffs and merge conflicts.

```yaml
formatters:
  enable:
    - gci
    - gofmt
    - gofumpt
    - goimports
  settings:
    gci:
      sections:
        - standard
        - default
        - prefix(github.com/example/app)
      custom-order: true
```

## Linter Tiers
Promote linters from opt-in to mandatory as the codebase proves them out.

| Tier | Linters | Use for |
|---|---|---|
| Minimal | `errcheck`, `govet`, `staticcheck`, `ineffassign`, `unused`, `gofmt`, `goimports` | Never disabled |
| Recommended | Minimal + `gosec`, `gocritic`, `revive`, `errorlint`, `nilerr`, `bodyclose`, `contextcheck`, `prealloc`, `misspell` | Default (`default: all` minus the noisy linters above) |
| Strict | Recommended + `gochecknoglobals`, `funlen`, `wrapcheck` | Opt-in per new package |

## `//nolint` Policy
A suppression always names the linter and gives a reason: `//nolint:<linter> // <reason>`. CI rejects bare `//nolint` (configure `nolintlint`).
- **Reason:** The reason tells the next reader why the check was bypassed; bare suppressions hide real bugs.

```go
// Good
//nolint:gosec // G404: math/rand is fine for jitter, not security-sensitive
n := rand.Intn(100)

// Bad
//nolint
//nolint:all
```

Never suppress instead of fixing `gosec` (security) or `errcheck` (ignored errors). Exempt generated files via `issues.exclude-files`, not per-file `//nolint`.

## Running the Linter
```bash
golangci-lint run ./...
```

## CI Integration
Always run in CI to block PRs with linting errors. **Pin the version** (never `latest`) so CI is reproducible — the same discipline as [`modules.md`](./modules.md).
```yaml
# GitHub Actions
- name: golangci-lint
  uses: golangci/golangci-lint-action@v7
  with:
    version: v2.1.6 # pin a real release; see github.com/golangci/golangci-lint/releases
```
