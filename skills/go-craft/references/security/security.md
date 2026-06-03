# Security Essentials

A practical checklist for Go services, organized by the OWASP Top 10 spine plus the project-specific rules that matter most. Default to deny, validate at the edge, and never trust client input.

## Hard Rules
1. **Never `fmt.Sprintf` SQL.** Always parameterized via `sqlx`/`squirrel` (see `data/database.md`). Even "internal" queries.
2. **Never `==` for secret comparison.** Use `subtle.ConstantTimeCompare` or a verify function (`bcrypt`/`argon2id`).
3. **Never log secrets or PII.** Tokens, passwords, emails, full bodies stay out of logs and span attributes (see `toolkit/observability.md`).
4. **Never accept a redirect/callback URL without an allowlist.** Prefix-exact, not substring.
5. **Never trust the client's content type.** Sniff with `http.DetectContentType` on the first 512 bytes.
6. **Never read secrets from env in business logic.** Only config loading reads env (see `recipes/config.md`).
7. **Validate at the boundary, then trust.** One validation pass at the transport edge.
8. **Default deny.** New endpoints are authenticated unless explicitly marked public and reviewed.

## Password Hashing
Use `argon2id` (preferred) or `bcrypt` — never a bare hash (SHA/MD5). Compare with the library's constant-time verify.
- **Reason:** Fast hashes are brute-forceable; argon2id is memory-hard. Constant-time comparison defeats timing attacks.

```go
// argon2id parameters: tune to ~hundreds of ms on your hardware
key := argon2.IDKey([]byte(password), salt, 3, 64*1024, 1, 32)
// verify with subtle.ConstantTimeCompare(key, stored)
```

Sane floor: memory ≥ 64 MB, iterations ≥ 3, parallelism 1; per-password random salt.

## Tokens (PASETO / JWT)
Prefer PASETO (no algorithm-confusion footguns) or carefully-configured JWT. Validate, don't just issue.
- **Reason:** The classic JWT bugs are `alg=none` and RS/HS confusion; PASETO removes the choice.

- [ ] Expiry (`exp`) enforced on parse, not only set.
- [ ] Audience/issuer validated.
- [ ] One signing key per service; support rotation via a key id.
- [ ] Secret loaded from config, never hardcoded or env-in-business-logic.

## Input Validation
Validate at the edge with proto constraints / a validation interceptor (see `recipes/grpc-api.md`). For dynamic SQL identifiers (column names from input), use an allowlist — never inline user strings.
- **Reason:** Centralized, declarative validation is auditable; identifier injection bypasses parameterization.

## File Uploads
- [ ] Max size enforced at the proxy **and** app (`http.MaxBytesReader`).
- [ ] Content type sniffed (`http.DetectContentType`), client header ignored.
- [ ] Allowlist of permitted types, not a denylist.
- [ ] Stored object key is an opaque UUID, not the user-supplied filename.
- [ ] Presigned URL TTL ≤ 15 min, scoped to one object and one verb.
- [ ] Strip EXIF from long-lived images; never render SVG inline (script vector).

## SSRF (Outbound Fetch)
Any server-side fetch (downloaders, webhooks, OAuth callbacks):
- [ ] URL host validated against an allowlist.
- [ ] Resolved IP rejected if private/loopback/link-local (`10/8`, `172.16/12`, `192.168/16`, `127/8`, `169.254.169.254`).
- [ ] Redirects bounded and re-validated each hop.
- [ ] Response size capped with `io.LimitReader`.
- **Reason:** SSRF reaches internal services and cloud metadata endpoints; allowlisting + IP checks close it.

## Secret Handling
Secrets enter via env → parsed by the config struct → injected through constructors. They never appear in logs, span attributes, error messages returned to clients, or VCS (`.env` is gitignored).
- **Reason:** Concentrating secret handling at the edge keeps the blast radius small and auditable. Rotate by accepting old+new for one window.

## PII in Logs and Traces
Allowed: opaque user/tenant IDs. Forbidden as labels/keys: email, phone, address, IP, full name, token/session id (hash if you must correlate), raw bodies.
- **Reason:** Telemetry is widely accessible and long-retained; PII there is a compliance and breach risk. See `toolkit/observability.md`.

## Dependencies
Run `govulncheck` in CI (see `toolkit/ci.md`); review dependency-update PRs; pin container base images to a digest.
- **Reason:** Most real-world breaches ride in via a known-vulnerable dependency.

For auth-flow specifics (login, sessions, OAuth), see `security/auth.md`.
