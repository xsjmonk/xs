# XS Language Agent Instructions

This repository is the standalone source of truth for the XS language skill.

For any `.xs` file, XS interpreter/site work, `clr.exe` script, XS grammar,
or XS extension API task, automatically apply `xs-language` before inspecting,
explaining, writing, reviewing, or debugging code. Do not ask the user to run
a skill command. If the skill is not already loaded, read the single canonical
file at `xs-language/SKILL.md` before continuing.

Use only the documentation and working scripts in this repository as the
language references. Do not import conventions from another XS repository.
When updating XS guidance, edit only `xs-language/SKILL.md`.

Tool routing:

- Cursor: `.cursor/rules/xs-language.mdc` and `.cursor/skills/xs-language`
- Codex: `CODEX.md` and the registered `xs-language` skill path
- Other AGENTS-aware agents: this file and `xs-language/SKILL.md`

All routes resolve to the same canonical skill file; do not create copies.
