# Breaking-Change Detection

Breaking detection compares your working schema against a baseline and fails when a change would break consumers. It is the automated enforcement of [`../schema/compatibility.md`](../schema/compatibility.md).

## Check against a stable baseline ref
Run the breaking check against the main branch (or the last release tag), not the previous commit.
- **Reason:** Comparing against `main` catches everything a PR changes relative to what consumers actually use; comparing against the prior commit misses breaks introduced earlier in the same branch.

```bash
easyp breaking --against <main-branch-or-release-tag>
# buf fallback:
buf breaking --against '.git#branch=main'
```

## Choose the wire-compatibility category
Use the wire-level breaking category (EasyP's default breaking set; buf's `WIRE`/`WIRE_JSON`), not just file-structure checks, for runtime-shared schemas.
- **Reason:** Wire categories flag the changes that actually corrupt data (renumbering, type-group crossings) and JSON-name changes that break REST clients. See [`../integration/json-mapping.md`](../integration/json-mapping.md).

```yaml
# buf.yaml — parity
breaking:
  use:
    - WIRE_JSON   # wire + JSON compatibility
```

## What counts as breaking
The detector flags the same operations the compatibility table forbids.
- **Reason:** Internalizing the list lets you predict a failure before CI does. See [`../schema/compatibility.md`](../schema/compatibility.md) and [`../style/fields.md`](../style/fields.md).

```text
BREAKING: change a field number; reuse a reserved/deleted number;
          change a field type across wire-compat groups;
          move a field in/out of a oneof; delete an RPC, field, or enum value
          without reserving; rename (breaks JSON_NAME / generated code).
SAFE:     add a field/message/enum value/RPC; reserve a removed field;
          mark deprecated.
```

## A required break ⇒ bump the version, don't suppress
If a change must break, introduce a new package version instead of ignoring the breaking failure.
- **Reason:** Suppressing the check ships the break to every existing client; a new version isolates it. See [`../api/versioning.md`](../api/versioning.md) and [`../schema/evolution.md`](../schema/evolution.md).

```bash
# Wrong: silence the failure.   Right: add acme/user/v2/ and check v2 against itself.
easyp breaking --against <release-tag>
```

## Gate every PR
Make the breaking check a required CI status on pull requests.
- **Reason:** Compatibility is only protected if a human can't merge past a red check; local runs are advisory. See [`ci.md`](./ci.md).

## Checklist
- [ ] Breaking check runs against `main`/a release tag, not the prior commit.
- [ ] Wire+JSON category enabled for runtime-shared schemas.
- [ ] Required breaks routed to a new version, never suppressed.
- [ ] Check is a required CI gate on PRs.
