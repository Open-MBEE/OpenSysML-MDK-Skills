# OpenSysML REDK Agent Skills

Skills that teach coding agents to use the
[OpenSysML](https://github.com/Open-MBEE/OpenSysML) Runtime Environment and Development Kit (REDK)
— the `sysml` binary (CLI, REPL, checking, documents, conversion, migration), the
`sysml-grpc` service, `sysml-lsp`, the `sysml-mcp` Model Context Protocol server, the Jupyter
kernel, the WebAssembly builds — and every
client library (Go, Python, Node/TypeScript, Java, Rust, Julia, MATLAB/Octave).

Each skill is a directory under `skills/` with a `SKILL.md` in the
[Agent Skills](https://agentskills.io) format, so Claude Code, Codex, Cursor, OpenCode,
Devin and other compatible agents can discover them. The content is written against the
OpenSysML documentation and verified against built binaries; version-specific numbers name
the release they were checked with.

## Installing the skills

Clone this repository and point your agent at `skills/`, or copy the directories you need
into the location your tool reads (for example `.claude/skills/`, `.agents/skills/`,
`.cursor/skills/` or `~/.config/opencode/skills/`). Skills reference each other by name
(`opensysml-install`, `opensysml-cli`, …), so keep the set together where practical.

## Skill catalog

### Binary and runtime

| Skill | Use when |
|---|---|
| [opensysml-install](skills/opensysml-install/SKILL.md) | Installing `sysml`, `sysml-lsp`, `sysml-grpc`, `sysml-jupyter-kernel`, `sysml-mcp`; `--tools all`; release verification; solver setup; how clients provision binaries |
| [opensysml-cli](skills/opensysml-cli/SKILL.md) | Non-interactive `sysml`: validate, evaluate, instantiate, run behaviors, `-json`, exit statuses, CI gates |
| [opensysml-repl](skills/opensysml-repl/SKILL.md) | Interactive `sysml` session and `%` commands; stepping actions and state machines |
| [opensysml-sysml-authoring](skills/opensysml-sysml-authoring/SKILL.md) | Writing `.sysml`/`.kerml` the tool accepts; imports, defaults vs fixed values, requirement usages, common diagnostics |
| [opensysml-checking](skills/opensysml-checking/SKILL.md) | Constraints, requirements, satisfaction, calculations, analyses, sweeps; holds / violated / undecided |
| [opensysml-analysis-engines](skills/opensysml-analysis-engines/SKILL.md) | `-engines`, `-engine auto\|name\|all`, standings, `-check-*` bounds, external engine manifests |
| [opensysml-service](skills/opensysml-service/SKILL.md) | Running `sysml-grpc`: ports, health, Connect JSON/protobuf, capabilities, the RPC surface |
| [opensysml-lsp](skills/opensysml-lsp/SKILL.md) | `sysml-lsp` and editor wiring (VS Code extension, OpenCode, generic LSP clients) |
| [opensysml-mcp](skills/opensysml-mcp/SKILL.md) | `sysml-mcp`, OpenSysML as MCP tools for coding agents: host configuration (`-print-config`), the `lsp`/`runtime`/`session` tool groups, which tool to call for a job |
| [opensysml-jupyter](skills/opensysml-jupyter/SKILL.md) | The Jupyter kernel: install, cells, rich output, notebook reuse |
| [opensysml-wasm](skills/opensysml-wasm/SKILL.md) | WASI and js/wasm builds, what runs in-process and what needs a native service |
| [opensysml-documents](skills/opensysml-documents/SKILL.md) | Rendering views and diagrams, generating Markdown/HTML/PDF documents |
| [opensysml-convert-rdf](skills/opensysml-convert-rdf/SKILL.md) | Turtle and API-JSON conversion and round-tripping |
| [opensysml-migrate-v1](skills/opensysml-migrate-v1/SKILL.md) | Migrating SysML v1 (XMI/UML/MagicDraw) models and reading the migration report |
| [opensysml-troubleshooting](skills/opensysml-troubleshooting/SKILL.md) | Environment variables, budgets, stale services, exit statuses, diagnosing failures |

### Modeling

| Skill | Use when |
|---|---|
| [opensysml-modeling-best-practices](skills/opensysml-modeling-best-practices/SKILL.md) | How to model so the result is spec-correct and loads in OpenSysML and the OMG pilot: actors as `actor` parameters, associations as `connection def`s, stereotypes as metadata, asserted constraints, performed actions, typed instances, views with optional layout; repairing a migrated v1 model |

### Client libraries

| Skill | Package |
|---|---|
| [opensysml-go](skills/opensysml-go/SKILL.md) | `github.com/Open-MBEE/OpenSysML/client/opensysml` — in-process `New()` or `Dial()` |
| [opensysml-python](skills/opensysml-python/SKILL.md) | `opensysml` on PyPI |
| [opensysml-node](skills/opensysml-node/SKILL.md) | `@openmbee/opensysml` (Node, browser, WASM) |
| [opensysml-java](skills/opensysml-java/SKILL.md) | `org.openmbee:opensysml` (JDK 17+) |
| [opensysml-rust](skills/opensysml-rust/SKILL.md) | `opensysml` on crates.io |
| [opensysml-julia](skills/opensysml-julia/SKILL.md) | `OpenSysML` (client/julia) |
| [opensysml-matlab](skills/opensysml-matlab/SKILL.md) | `+opensysml` (client/matlab, MATLAB and Octave) |

## Contributing

- One directory per skill; `name` in the frontmatter must equal the directory name.
- Keep `SKILL.md` focused and under ~500 lines; put long material in `references/` and
  helper scripts in `scripts/` inside the skill.
- Verify every command and API name against the OpenSysML source, documentation or a built
  binary before documenting it, and prefer the vocabulary the tool itself prints.
- Run the checks before opening a pull request:

```bash
python3 scripts/validate-skills.py   # frontmatter, naming, size limits
python3 scripts/check-links.py       # relative links resolve
```

The same checks run in CI (`.github/workflows/validate.yml`).

## License

Apache-2.0, matching OpenSysML. See [LICENSE](LICENSE).
