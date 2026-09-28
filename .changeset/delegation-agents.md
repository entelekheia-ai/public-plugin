---
"delegation": minor
---

The `plan-scout`, `blind-run` and `reviewer` agents, and the read-only guard they share, shipped as the plugin's own `PreToolUse` hook because Claude Code ignores a plugin agent's `hooks:` field.
