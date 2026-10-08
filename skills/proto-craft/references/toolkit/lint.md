# Linting

Linting enforces the conventions in `style/` and `api/` mechanically. Adopt the recommended rule set, opt out only with intent, and fix violations rather than silencing them.

## Adopt the recommended rule set
Enable the standard preset rather than hand-picking rules.
- **Reason:** The curated set encodes community consensus (naming, enum zero value, package-version suffix, comment requirements) that matches this skill's `style/` rules; cherry-picking drifts from convention. See [`easyp.md`](./easyp.md).

```yaml
# easyp.yaml
version: v1
linters:
  default: STANDARD   # MINIMAL + BASIC + DEFAULT rules; buf fallback: lint.use [STANDARD]
  enable:
    - COMMENTS        # doc comments on public symbols (style/comments.md)
```

## Opt out per-rule, with a reason
If a rule genuinely doesn't fit, disable that single rule in config with a comment explaining why — never disable whole categories.
- **Reason:** A targeted, documented exception is auditable; a blanket opt-out quietly erodes the whole style baseline.

```yaml
linters:
  default: STANDARD
  disable:
    - PACKAGE_VERSION_SUFFIX   # internal-only package; versioned at the gateway
issues:
  exclude-rules:
    - path: api/legacy/**      # frozen legacy schema; rewritten in v2
      linters: [FIELD_LOWER_SNAKE_CASE]
```

For a single declaration, use an inline directive that names the rule: `// easyp:disable FIELD_LOWER_SNAKE_CASE` above the declaration. `// easyp:off` is not valid and fails the whole lint run.

## Key rules map to this skill's conventions
The high-value lint rules enforce the same things `style/` mandates.
- **Reason:** Knowing the mapping lets you fix the root cause (the convention) rather than chase the lint code. See [`../style/naming.md`](../style/naming.md) and [`../style/enums.md`](../style/enums.md).

```text
ENUM_ZERO_VALUE_SUFFIX        → first enum value is *_UNSPECIFIED = 0   (style/enums.md)
ENUM_VALUE_PREFIX             → CONSTANT_CASE values prefixed by enum   (style/enums.md)
PACKAGE_VERSION_SUFFIX        → package ends in .vN                     (api/versioning.md)
PACKAGE_DIRECTORY_MATCH       → file path matches package              (style/files.md)
FIELD_LOWER_SNAKE_CASE        → field names lower_snake_case           (style/naming.md)
RPC_REQUEST/RESPONSE_*        → distinct named XRequest/XResponse       (api/services.md)
COMMENT_*                     → doc comments on public symbols          (style/comments.md)
```

## Fix the schema, not the linter
When lint fails, change the `.proto` to comply; reserve config opt-outs for true false positives.
- **Reason:** Lint failures usually point at a real future-compatibility or ergonomics problem; silencing them ships the problem to consumers.

```bash
easyp lint   # buf fallback: buf lint
```

## Format on save / pre-commit
Run a formatter to normalize whitespace and layout; don't hand-align. EasyP has no formatter, so use `buf format -w` as a standalone tool.
- **Reason:** Consistent formatting keeps diffs minimal and frees review for substance. See [`../style/files.md`](../style/files.md).

```bash
buf format -w   # EasyP has no format command
```

## Checklist
- [ ] `linters.default: STANDARD` (or stricter) enabled.
- [ ] Opt-outs are per-rule and commented.
- [ ] Violations fixed in the schema, not silenced.
- [ ] Formatter run before commit.
