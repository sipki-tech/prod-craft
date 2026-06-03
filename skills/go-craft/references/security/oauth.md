# OAuth / OIDC Provider Integration

Verifying third-party identities (Google, GitHub, Apple, ...) and linking them to local accounts. Companion to [`auth.md`](./auth.md) (sessions, login). Focus here: the **adapter** and **token validation**.

## Provider Behind an Interface
The app layer defines a tiny contract; each provider is an adapter implementing it. The app never imports provider SDKs.

```go
// app/contracts.go
type OAuthUserInfo struct {
    ID    string // stable provider-side user id (the 'sub' claim)
    Email string
    Name  string
}

type OAuthProvider interface {
    // Validate checks the token and returns verified user info.
    // Errors: ErrInvalidToken, unknown.
    Validate(ctx context.Context, token string) (*OAuthUserInfo, error)
}
```

Dispatch by a provider-kind enum and a registry:

```go
type ProviderKind string

const (
    ProviderKindGoogle ProviderKind = "google"
    ProviderKindGitHub ProviderKind = "github"
    ProviderKindApple  ProviderKind = "apple"
)

p, ok := providers[kind] // map[ProviderKind]OAuthProvider
if !ok {
    return ErrProviderNotFound
}
```

## Validate ID Tokens via JWKS — Never Trust Claims Blindly
For OIDC providers, validate the ID token's **signature** against the provider's published JWKS, then check claims. Use the provider's verification library where available (it fetches and caches JWKS for you).

```go
// Google example: idtoken.Validate fetches Google's keys and verifies signature + exp.
payload, err := idtoken.Validate(ctx, rawIDToken, clientID)
if err != nil {
    return nil, fmt.Errorf("%w: %w", ErrInvalidToken, err)
}
sub, _ := payload.Claims["sub"].(string)
if sub == "" {
    return nil, ErrInvalidToken
}
```

Verify, at minimum:

- **Signature** — against current JWKS (keys rotate; cache with a TTL, refetch on unknown `kid`).
- **aud (audience)** — equals **your** client id. Reject tokens minted for another app.
- **iss (issuer)** — exactly the expected issuer URL.
- **exp / iat** — not expired, not future-dated (allow small clock skew).
- **nonce** — matches the nonce you sent (replay protection) in the auth-code/implicit flows.

## Authorization Code Flow + PKCE
Prefer the authorization-code flow with PKCE (mandatory for public clients, recommended for all). Per login attempt, generate and store **server-side**, tied to the session:

- **state** — random, opaque; verified on callback (CSRF protection for the redirect).
- **nonce** — random; embedded in the auth request and checked in the ID token.
- **code_verifier** — random; send its `S256` hash as `code_challenge`, then the verifier on token exchange.

Exchange the code **server-side** (the client secret never reaches the browser). See the broader flow in [`auth.md`](./auth.md).

## Redirect URI Allowlist
Register exact redirect URIs with the provider and validate them on your side. Never reflect a user-supplied `redirect_uri` / `return_to` without allowlisting — open redirects enable code/token theft.

## Account Linking Policy
Decide deliberately how a provider identity maps to a local user:

- **Look up by `(provider, provider_user_id)` first** — the stable key (e.g. a `UserByOAuthID` repo method).
- **Do not auto-link by email** unless the provider asserts the email is verified, and even then treat it as sensitive — prefer an explicit "link account" confirmation while the user is logged in.
- **Store the provider id, not just the email** — emails change and can be reassigned.

## Token Storage & Rotation
- **Encrypt provider refresh tokens at rest** — they're long-lived credentials.
- **Rotate refresh tokens on use** where the provider supports it; revoke on logout/unlink.
- **Keep access tokens server-side** — never expose them to the browser.

## Provider Quirks (call them out)
- **Apple** — returns the user's name only on the first authorization; offers private email relay; tokens signed with rotating keys.
- **Google** — supports the `hd` hint for hosted domains; the `email_verified` claim matters for linking.
- **GitHub** — not OIDC by default; email may require a separate scope/endpoint and can be private.

## Errors
Convert provider/validation failures to a domain sentinel (`ErrInvalidToken`) at the adapter boundary; wrap the cause with `%w`. Never log tokens or provider internals (see [`security.md`](./security.md) PII rules).

## Checklist
- [ ] Provider behind an app interface; SDKs stay in the adapter.
- [ ] ID-token signature verified via JWKS; `aud`/`iss`/`exp`/`nonce` checked.
- [ ] Auth-code flow + PKCE; `state` and `nonce` stored server-side and verified.
- [ ] Redirect URIs allowlisted; no reflected redirects.
- [ ] Linking by `(provider, provider_id)`; email-linking only if verified + explicit.
- [ ] Refresh tokens encrypted, rotated, revocable; tokens never sent to the browser.
- [ ] Validation failures map to `ErrInvalidToken`; no token/PII leakage in logs.
