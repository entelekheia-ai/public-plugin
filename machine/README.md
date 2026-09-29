# machine

**Keep a development machine working.** `machine` reclaims disk space that regenerable development
caches quietly consume on macOS, and restores the VS Code agents panel when a model picker comes up
empty after an update.

## Skills

| Command | Fires when |
|---|---|
| `/machine:dev-storage` | The disk is filling, after cloning repositories, or on a monthly cadence — reports where space went, excludes regenerable caches and build output from Time Machine, deletes them, and thins the APFS snapshots that otherwise pin every freed block. |
| `/machine:repair-agent-host` | The agents window offers no Anthropic models, a Claude or Codex session refuses to start, or confirming after a VS Code update that a Claude subscription is still the billing path rather than a Copilot seat. |

## Requirements

macOS. `dev-storage` drives `tmutil` and APFS local snapshots directly; `repair-agent-host` targets VS
Code's own Agent Host SDK and log files.

## Install

```sh
claude plugin install machine@entelekheia
```
