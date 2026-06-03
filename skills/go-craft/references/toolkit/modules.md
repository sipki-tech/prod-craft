# Go Modules & Dependency Hygiene

A reproducible, auditable dependency graph. The module files are part of your source — review them like code.

## `go.mod` / `go.sum`
- **`go.mod`** declares the module path, the Go version, and direct/indirect requirements.
- **`go.sum`** pins cryptographic checksums for every module version in the graph. **Commit both.** Never `.gitignore` `go.sum`.
- **`go mod tidy`** adds what's imported and removes what isn't. Run it after changing imports and commit the result; a dirty `tidy` in CI should fail the build (see [`ci.md`](./ci.md)).
- **`go mod verify`** checks that cached modules match `go.sum`.

```bash
go mod tidy        # reconcile go.mod/go.sum with actual imports
go mod verify      # checksums match what's on disk
go mod why <pkg>   # explain why a dependency is in the graph
go mod graph       # print the full dependency graph
```

## Versioning Rules (SemVer Import Compatibility)
- Go uses **semantic import versioning**: a `v2+` module carries its major version in the path (`example.com/lib/v2`). `v2` is a *different import path* from `v1`, so they can coexist.
- **Pin to released tags**, not branches. A pseudo-version (`v0.0.0-2024...-abcdef`) outside a short-lived spike is a smell.
- The `go` directive sets the **minimum** language version; bump it deliberately, not by accident.

## Minimal Version Selection (MVS)
Go picks the **lowest** version that satisfies all requirements, so builds are deterministic without a separate lockfile resolver. Upgrade explicitly:
```bash
go get example.com/lib@v1.5.0   # a specific version
go get example.com/lib@latest   # latest release
go get -u ./...                 # upgrade direct + indirect to latest minor/patch
```

## `replace` and `exclude`
- **`replace`** redirects a module to a fork or local path. Fine for local multi-module dev; **don't ship** `replace ../local` to consumers — it breaks `go get` of your module.
- Prefer **`go.work`** (below) over `replace` for local cross-module work.
- **`exclude`** skips a known-bad version; leave a comment explaining why.

## Multi-Module Workspaces (`go.work`)
For developing several modules together (a service plus its client lib), a workspace stitches them without editing each `go.mod`:
```bash
go work init ./service ./client
go work use ./newmodule
```
- **Commit `go.work` only** in repos meant to be developed as a workspace; otherwise `.gitignore` it so it doesn't override a consumer's resolution.

## Vendoring (optional)
`go mod vendor` writes dependencies into `vendor/`. Use it when builds must be hermetic/offline or for supply-chain review; the cost is a large diff and manual refreshes. Most setups rely on the module cache plus `go.sum` instead.

## Tool Dependencies
Pin the versions of code generators and linters so every machine and CI runs the same tool:
- A **`tool` directive** in `go.mod` (Go 1.24+), or a `tools.go` with blank imports under a build tag (older toolchains).
- Or pinned versions in the task runner ([`../../assets/Taskfile.yml`](../../assets/Taskfile.yml)) via `go run pkg@version`.

## Supply-Chain Safety
- **`govulncheck ./...`** reports known vulnerabilities your code actually reaches. Run it in CI (`ci.md`).
- Review `go.sum` diffs in PRs; an unexpected transitive bump deserves a `go mod why`.
- Prefer fewer, well-maintained dependencies — a one-line helper isn't worth a deep transitive tree.

## Checklist
- [ ] `go.mod` and `go.sum` committed; `go mod tidy` is clean in CI.
- [ ] Dependencies pinned to released tags; no stray pseudo-versions.
- [ ] No `replace` directives shipped to consumers.
- [ ] `go.work` committed only where the repo is a workspace.
- [ ] Tool versions pinned and reproducible.
- [ ] `govulncheck` runs in CI; `go.sum` diffs reviewed.
