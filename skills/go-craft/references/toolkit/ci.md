# Continuous Integration

CI is the enforcement point for everything in this skill: format, lint, vet, tests with `-race`, generated-artifact freshness, and vulnerability scanning. Make it fast and deterministic.

## One Entry Point: `task lint`
Expose a single command that runs the full gate locally and in CI: format check, `golangci-lint`, `buf lint`, unit tests, build.
- **Reason:** "Works on my machine" disappears when local and CI run the identical command. See `toolkit/dev.md`.

```yaml
# Taskfile.yml
lint:
  deps: [test-unit, build]
  cmds:
    - "golangci-lint run ./..."
    - "buf lint"
```

## Tests with `-race` and Coverage
Run unit tests with the race detector and `-count=1` (disable caching) in CI.
- **Reason:** Parallel tests (see `testing/parallel.md`) surface races; CI is where they must be caught, not suppressed.

```bash
gotestsum --format pkgname -- -race -count=1 -coverprofile=cover.out ./...
```

## PR-Scoped Linting
On pull requests, block on **new** findings only with `--new-from-rev`, so legacy debt doesn't fail unrelated PRs.
- **Reason:** Lets you adopt stricter linters incrementally without a giant cleanup PR.

```bash
golangci-lint run --new-from-rev=origin/main --timeout=5m ./...
```

## Pin Tool Versions
Pin `golangci-lint`, `buf`, `gotestsum`, and codegen plugin versions in CI.
- **Reason:** A floating `latest` causes mysterious failures when a tool ships new defaults. Pinning makes CI reproducible.

```yaml
- uses: golangci/golangci-lint-action@v6
  with:
    version: v1.61.0 # pinned
```

## Verify Generated Artifacts Are Fresh
Run codegen, then fail if the working tree changed.
- **Reason:** Guarantees committed mocks, proto output, and stringers match their sources (no "forgot to regenerate").

```bash
go generate ./...
buf generate
git diff --exit-code   # nonzero if anything regenerated differently
```

## Vulnerability Scanning
Run `govulncheck` on every build; scan container base images.
- **Reason:** Catches known CVEs in dependencies and the standard library before release.

```bash
go run golang.org/x/vuln/cmd/govulncheck@latest ./...
```

## Integration Tests in CI
Run the `integration`-tagged suite against Docker services (`testing/integration.md`). Pre-pull images to avoid first-run flakiness.
- **Reason:** Integration coverage only protects you if it runs in CI, not just locally.

```bash
go test -tags=integration -race -count=1 ./...
```

## Build for Target Platforms
Cross-compile the release artifact deterministically (e.g. `CGO_ENABLED=0`, pinned Go version) and build the container image.
- **Reason:** A reproducible, statically linked binary deploys predictably across environments.

## Don't Commit Build Output or Secrets
`bin/`, `.cover/`, `.env`, and local secrets are gitignored; CI fails if they appear.
- **Reason:** Keeps the repo clean and prevents credential leaks (see `security/security.md`).
