# Authentication & Sessions

Authenticate at the transport edge, carry a typed identity in the context, and store revocable sessions server-side. This file covers login, sessions, and OAuth; password/token primitives are in `security/security.md`.

## Identity Lives in the Context — at the Edge Only
The transport layer validates the bearer token, loads the session, and puts a typed `*Session` into the context. Layers below read it as an explicit parameter, not from the context.
- **Reason:** Reading the session from context deep in the stack hides a dependency and makes business logic untestable. Extract once at the edge; pass it down. See `recipes/middleware.md` and `style/context.md`.

```go
// transport interceptor/middleware
session, err := auth.Auth(ctx, bearerToken)
if err != nil {
    return status.Error(codes.Unauthenticated, "invalid auth")
}
ctx = session.NewContext(ctx, session)
// app methods take the session explicitly:
func (a *App) UpdateUser(ctx context.Context, s app.Session, ...) error
```

## Login Without Account Enumeration
Return an identical error for "no such user" and "wrong password". Do the password compare even when the user doesn't exist (compare against a dummy hash) to equalize timing.
- **Reason:** Distinct errors or response times let an attacker enumerate valid accounts.

```go
u, err := a.repo.UserByEmail(ctx, email)
switch {
case errors.Is(err, app.ErrNotFound):
    a.hash.Compare(ctx, dummyHash, []byte(pass)) // equalize timing
    return app.ErrInvalidAuth                     // same error as wrong password
case err != nil:
    return fmt.Errorf("a.repo.UserByEmail: %w", err)
}
if !a.hash.Compare(ctx, u.PassHash, []byte(pass)) {
    return app.ErrInvalidAuth
}
```

## Server-Side Sessions with TTL
Store sessions in Redis keyed `app:sess:<id>` with TTL = token lifetime (see `data/caching.md`). The token references the session; the session is the source of truth for validity.
- **Reason:** Server-side sessions are revocable; a stateless token alone cannot be invalidated before expiry.

- [ ] TTL = token lifetime; refresh extends it.
- [ ] Logout deletes the session server-side (not just clears the client).
- [ ] Rotate the session id on privilege change to prevent fixation.

## Brute-Force Protection
Rate-limit login per IP **and** per account (sliding window in Redis; see `data/caching.md`).
- **Reason:** Per-IP alone misses distributed attacks; per-account alone lets one IP spray many accounts.

## OAuth / OIDC
- [ ] `state` is cryptographically random (≥128 bits), stored server-side with TTL, checked on callback.
- [ ] PKCE (`S256`, never `plain`) on the authorization-code flow.
- [ ] `nonce` checked on the ID token.
- [ ] Redirect URI matched against an allowlist (prefix-exact, not substring).
- [ ] ID token fully validated: signature against JWKS, `iss`, `aud`, `exp`, `iat`, `nonce`.
- [ ] JWKS cached with bounded TTL; refresh on `kid` miss.
- [ ] Account linking only by a **verified** email; otherwise require explicit confirmation.
- [ ] Refresh tokens stored encrypted at rest, rotated on use, never logged.
- **Reason:** `state` defeats CSRF on the callback, PKCE defeats code interception, `nonce` defeats ID-token replay, and the redirect allowlist defeats open-redirect token theft.

## Authorization (Access Control)
Check ownership/role on every resource access, not just authentication. A valid session is not permission to touch *any* object.
- **Reason:** IDOR (accessing another user's resource by guessing its id) is among the most common real vulnerabilities. Verify `resource.OwnerID == session.UserID` (or a role/tenant check) in the app layer.

```go
if file.OwnerID != session.UserID {
    return app.ErrAccessDenied // -> PERMISSION_DENIED (see recipes/grpc-api.md)
}
```

## CSRF Posture
A bearer-token API (Authorization header) is largely CSRF-immune. If you ever authenticate via cookies for a browser SPA, add `SameSite`, a CSRF token on state-changing requests, and an Origin/Referer check.
- **Reason:** CSRF rides ambient cookie credentials; header tokens aren't sent automatically by the browser.
