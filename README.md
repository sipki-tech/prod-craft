<p align="center">
  <strong>prod-craft</strong><br/>
  <em>Production-grade skills for languages and tools</em>
</p>

<p align="center">
  <a href="#what-is-prod-craft">What</a> ·
  <a href="#available-skills">Skills</a> ·
  <a href="#installation">Install</a> ·
  <a href="#philosophy">Philosophy</a> ·
  <a href="./ROADMAP.md">Roadmap</a>
</p>

---

## What is prod-craft?

**prod-craft** is a curated collection of AI agent skills that encode production-grade standards for programming languages and developer tools.

These are not tutorials. Each skill is a distilled body of knowledge — style guides, architecture patterns, tooling configs, review checklists, and ready-to-use assets — designed for experienced developers who ship to production.

Install a skill, and your AI coding assistant immediately knows:
- **How** to write idiomatic, maintainable code in that language.
- **What** tooling, linting, and CI gates to enforce.
- **When** patterns apply and when they don't.
- **Why** each convention exists — not just the rule, but the rationale.

## Available Skills

| Skill | Language / Tool | Focus |
|---|---|---|
| [`go-craft`](./skills/go-craft/) | Go (Golang) | Idiomatic style, clean architecture, testing, data access, observability, security, tooling |
| [`proto-craft`](./skills/proto-craft/) | Protocol Buffers / gRPC | Schema design, wire compatibility, API design (AIPs), EasyP toolchain, protovalidate |

> More skills are planned — see the [Roadmap](./ROADMAP.md).

## Installation

Skills are distributed via the [Vercel `npx skills` CLI](https://github.com/nicepkg/vercel-skills):

```bash
# Install a single skill
npx skills install sipki-tech/prod-craft --skill go-craft

# Install all skills from this repo
npx skills install sipki-tech/prod-craft
```

After installation, the skills are automatically picked up by compatible AI agents (Claude Code, Cursor, Copilot, Codex, Gemini, etc.).

## Philosophy

1. **Craft, not syntax.** We assume you know the language. Skills focus on the hard-won patterns that separate prototypes from production systems.

2. **Opinionated with rationale.** Every rule includes a *Reason* explaining why it exists. Disagree? Override it — but know what you're giving up.

3. **Load only what you need.** Each skill is modular: a `SKILL.md` entry point, a `MAP.md` navigation map, and fine-grained `references/` files. The agent loads only the files relevant to the current task.

4. **Assets you can copy-paste.** Starter configs (linters, CI, Taskfiles, proto configs) live in `assets/` — ready to drop into your repo.

5. **Production-first tooling.** EasyP over buf. golangci-lint with an opinionated rule set. `-race` always. Every convention is CI-enforceable.

## Repository Structure

```
prod-craft/
├── skills/
│   ├── go-craft/           # Go professional standards
│   │   ├── SKILL.md        # Entry point & review checklist
│   │   ├── MAP.md          # Navigation map
│   │   ├── references/     # Deep-dive docs (style, arch, data, testing, ...)
│   │   └── assets/         # Starter configs & templates
│   └── proto-craft/        # Protocol Buffers & gRPC standards
│       ├── SKILL.md
│       ├── MAP.md
│       ├── references/     # Deep-dive docs (style, schema, api, toolkit, ...)
│       └── assets/         # Starter configs (easyp.yaml, Taskfile, example.proto)
├── ROADMAP.md              # Planned skills & milestones
└── skills-lock.json        # Installed external skills lock
```

## Contributing

1. Fork the repo.
2. Create a skill directory under `skills/` following the existing structure.
3. Every reference file must include a **Reason** for each rule and a **Checklist** at the end.
4. Submit a PR — the review checklist from the relevant `SKILL.md` applies to itself.

## License

MIT
