# Versioning

The version lives in the package path. Evolve in place while you can; bump the version only for a breaking redesign, and run versions in parallel during migration.

## Version in the package path
Put the major version as the last package segment: `acme.user.v1`. The directory mirrors it: `acme/user/v1/`.
- **Reason:** The version becomes part of every generated symbol and import path, so v1 and v2 types never collide and clients pin a version explicitly. See [`../style/files.md`](../style/files.md).

```proto
syntax = "proto3";
package acme.user.v1;
option go_package = "github.com/acme/api/gen/user/v1;userv1";
```

## Evolve in place for additive changes
Stay on the current version for any backward-compatible change (new fields, messages, enum values, RPCs).
- **Reason:** A version bump is expensive for every consumer; additive changes need no bump and keep one contract. Reserve bumps for changes that cannot be additive. See [`../schema/evolution.md`](../schema/evolution.md).

```proto
// Still acme.user.v1 — added additively:
message User {
  string id = 1;
  string email = 2;
  string display_name = 3; // new, safe
}
```

## Bump only for breaking redesigns
Create `v(N+1)` when a change cannot be made compatibly: renumbering, type changes across wire groups, removing/renaming required behavior, or a structural redesign.
- **Reason:** A new version isolates the break so existing clients keep working on the old one. Mutating v1 breaks everyone at once. See [`../schema/compatibility.md`](../schema/compatibility.md).

```proto
// New package for the breaking redesign:
package acme.user.v2;
option go_package = "github.com/acme/api/gen/user/v2;userv2";
```

## Run v1 and v2 in parallel during migration
Serve both versions simultaneously; register both services and let clients migrate on their own schedule.
- **Reason:** Parallel versions turn a hard cutover into a gradual migration with no flag day. Keep them side by side until v1 traffic drains.

```proto
// Both packages generate independent services that the server can register together.
// acme/user/v1/user.proto  → UserService (v1)
// acme/user/v2/user.proto  → UserService (v2)
```

## Announce a deprecation timeline
When introducing v2, mark v1 deprecated with a documented sunset date and track v1 usage to schedule removal.
- **Reason:** A published timeline gives clients a deadline and you the justification to delete v1; open-ended deprecations never complete. See [`../style/comments.md`](../style/comments.md).

```proto
// acme.user.v1 — Deprecated: migrate to acme.user.v2 by 2026-Q4; v1 removed thereafter.
service UserService {
  option deprecated = true;
}
```

## Don't use minor versions in the path
Use only a major version (`v1`, `v2`) in the package — not `v1beta1` semantics for stable APIs or `v1.2` path segments.
- **Reason:** Minor/patch changes are, by definition, compatible and need no new path; encoding them in the package would fragment imports for non-breaking changes. (A `vNbetaM` channel is fine for explicitly unstable previews.)

## Checklist
- [ ] Major version is the last package segment; directory matches.
- [ ] Additive changes stay in the current version.
- [ ] Breaking changes go to a new `v(N+1)` package.
- [ ] Old and new versions served in parallel during migration.
- [ ] Deprecation has a documented sunset date and usage tracking.
- [ ] No minor/patch versions encoded in the package path.
