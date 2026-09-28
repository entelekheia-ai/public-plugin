---
name: repair-agent-host
description: "Restore the models in the VS Code agents panel when the picker comes up empty — a VS Code update raises the Agent Host SDK version, the cached SDK stays behind, and the host then reports zero models while the panel reads as switched off. Use when the agents window offers no Anthropic models, when a Claude or Codex session refuses to start, when agenthost.log reports `Models refreshed (merged). Count: 0`, or to confirm after an update that a Claude subscription is still the billing path rather than a Copilot seat."
disable-model-invocation: true
user-invocable: true
user_invocable: true
---

# Repair the VS Code agent host

**Before starting, read your notes for this skill**, where they exist — `~/.agents/skill-notes/repair-agent-host.md`,
then `.agents/skill-notes/repair-agent-host.md`, then `.agents/skill-notes/repair-agent-host.local.md`. Where two
disagree, the more specific one wins. They hold what earlier runs taught; see the last section for how they are
written.

The agents panel runs its Claude and Codex sessions through the **Agent Host**, a VS Code process that
loads a separate SDK per agent from a cache under the user-data directory. `product.json` pins the
version it will load, and the panel shows the models only once that exact version is on disk. At the end
of this procedure the picker offers models again and the credential billing them is the intended one.

**`install-sdk.sh` writes into VS Code's own SDK cache** — application state under the user-data
directory (`agent-host/sdk-cache/<agent>/<version>/<sdkTarget>/`), the same place VS Code's own in-app
download writes. It never touches the app's `product.json` or settings. To undo it, delete the version
directory it created (`rm -rf` the path the script printed as `installed …`); VS Code re-downloads it
itself the next time a session needs it, or the script can be re-run.

**This is a target-state skill.** The correct shape is the cache holding the pinned version plus the
credential the panel is supposed to bill; a second run repairs whatever drifted. Pass `audit` to run
Step 0 alone, which writes nothing.

## Step 0 — The symptom, read from the log rather than the panel

```sh
${CLAUDE_SKILL_DIR}/scripts/sdk-status.sh
```

It prints, per agent, the version `product.json` requires against the versions cached on disk, then the
last model counts from the newest `agenthost.log`. It writes nothing and needs no `sudo` — it only reads
under the VS Code app and user-data directories — and exits `1` when any required version is absent.

**Read the log line, not the panel.** A missing SDK, a missing credential and a revoked GitHub sign-in
all produce the same empty picker, and only the log separates them:

| The log says | What it means |
|---|---|
| `[Claude] Models refreshed (merged). Count: 0` | no models from either source — continue to Step 1 |
| `SDK not downloaded yet; deferring chat metadata` | the pinned SDK is absent from the cache — Step 2 fixes it |
| `Failed to fetch native models` | the SDK loaded and the credential was refused — skip to Step 3 |
| `Models refreshed (merged). Count: 7, …` | the host is healthy; the fault is elsewhere |

**One log carries every agent, and each line names its own.** The `[Claude]` and `[Codex]` prefixes are
what attribute a line, so a `Count: 0` for an agent nobody uses says nothing about the one whose panel is
empty. The script prints the prefixes; read them rather than the totals.

**A log line older than the cache describes a previous startup.** The agent host writes these lines at
launch, so an install done since then leaves a healthy cache sitting under a failing log. The script says
so when it sees that gap, and Step 4 is what settles it.

An `audit` run stops here and reports what the script printed.

## Step 1 — The version gap, named

The host loads `<user data>/agent-host/sdk-cache/<agent>/<version>/<sdkTarget>/`, and treats the cache as
usable only when an empty `.complete` file sits at the root of that directory. `<version>` comes from
`agentSdks.<agent>.version` in the installation's `product.json`; `<sdkTarget>` is `<platform>-<arch>`
(`darwin-arm64`, `linux-x64`), with a `-musl` suffix on a musl Linux.

An update rewrites `product.json` and leaves the cache untouched, so the pinned version changes and
nothing on disk matches it. The old directory stays valid-looking beside the gap.

**A missing SDK for an agent nobody uses is the expected state, not a fault.** The host downloads an
agent's SDK the first time a session needs it, so an agent left disabled never populates its cache. Act
only on the agent whose panel is empty.

## Step 2 — The SDK installed at the version the app requires

Two routes reach the same directory.

**Inside VS Code**, the chat view offers a download action on the error it raises when the SDK is
missing. That action is the command `workbench.action.chat.agentHost.downloadAgentSdk`, registered with
the agent id as an argument and therefore absent from the Command Palette — the button in the view is the
only way to reach it by hand.

**From a shell**, when no window is available or the in-app download fails:

```sh
${CLAUDE_SKILL_DIR}/scripts/install-sdk.sh claude
```

It reads the pinned version and `urlTemplate` from `product.json`, substitutes `{sdkTarget}`, downloads
the tarball, refuses anything whose root is not `node_modules/`, extracts with no component stripped,
writes the `.complete` marker, and moves the finished directory into place in one step. It then loads
`@anthropic-ai/claude-agent-sdk` through `createRequire` and checks that `query()` is exported, because a
directory of the right shape that fails to load looks identical to a working one until a session starts.
Re-running against a complete cache prints that and changes nothing.

**Needs no `sudo`; it writes into the SDK cache under the user-data directory** (see the note above on
undoing it), and it needs `curl`, `tar` and `node` on `PATH` — it fails with a written message when one
is missing.

**That load check runs for `claude` alone**, because it names `@anthropic-ai/claude-agent-sdk`. A Codex
install is confirmed only as far as the tarball root, the extraction and the marker; the first session is
what proves it loads.

**The built-in download is on demand and its failure surfaces nowhere anyone looks.** It runs when a
session first needs the SDK, and a refusal leaves the panel looking switched off rather than broken. That
is why a shell route exists for a file VS Code would otherwise fetch itself.

## Step 3 — The subscription confirmed as the billing path

Reach this step when the SDK is present and the picker is still empty, or when an update may have moved
the credential. Four things carry it, and all four are edited by hand:

- **The credential.** `CLAUDE_CODE_OAUTH_TOKEN` in the `env` object of `~/.claude/settings.json`, created
  by `claude setup-token`. That token bills the Claude subscription. `ANTHROPIC_API_KEY` in the same
  place bills an Anthropic API account instead, so the two are a choice rather than alternatives.
- **`chat.agentHost.allowSignedOutWhenUsable: true`** in the VS Code user settings, which lets the agents
  window open while signed out of GitHub. The picker then shows Anthropic-native models alone; signing in
  to GitHub adds the Copilot-routed ones beside them, billed to the Copilot seat.
- **`chat.agentHost.claudeAgent.enabled`**, which defaults to `true`. Set it explicitly only where an
  enterprise policy turned it off.
- **`<user data>/User/chatLanguageModels.json`**, when a model is pinned there. It must parse: a
  duplicated key is silently resolved last-wins, so a hand edit can leave a file that reads correctly and
  behaves as its later half.

**The settings sit one directory deeper than the cache.** `agent-host/` and `logs/` are children of the
user-data directory itself; everything a person edits is under `User/` inside it. A path built from the
`user data` line the status script prints therefore needs `User/` added.

**A second copy of `chatLanguageModels.json` exists and is usually inert.** The agents window runs under
its own profile, at `<user data>/User/profiles/<location>/chatLanguageModels.json`. Whether that copy is
read is decided by `userDataProfiles[].useDefaultFlags.languageModels` in
`<user data>/User/globalStorage/storage.json`: `true` means the profile inherits the file above and its
own copy is ignored, however full or empty it looks. Check the flag before editing either file.

`<user data>/User/globalStorage/agent-host-config.json` mirrors what the host resolved from those
settings — `allowSignedOutWhenUsable`, `byokModelsEnabled`, `codexAgentEnabled`. Read it to confirm a
setting arrived. VS Code writes it, so an edit there is overwritten.

## Step 4 — The models counted after a restart

The agent host reads the cache at startup, so the panel stays empty until VS Code restarts. Restart it,
then:

```sh
${CLAUDE_SKILL_DIR}/scripts/sdk-status.sh
```

The pass criterion is a `Models refreshed (merged). Count:` line above zero, timestamped after the
restart.

**A sandboxed shell cannot open or drive the VS Code window**, so this log line is the verification. A
claim that the panel was seen working belongs only to whoever looked at the screen.

## Checklist

- [ ] `sdk-status.sh` ran, and the log line separating a missing SDK from a refused credential was read
- [ ] The agent acted on is one whose panel is actually empty, rather than one left disabled
- [ ] The pinned version from `product.json` and the cached directories were compared, marker included
- [ ] The SDK for that version is installed and loads, either through the in-app action or the script
- [ ] The credential and the two settings that route billing were confirmed, and `chatLanguageModels.json` parses
- [ ] VS Code restarted, and a model count above zero was read from a line newer than the restart

## ⟳ After every use: note what this run taught

**Never edit this file** — it is an installed copy, and the next update overwrites it without a word.
Write what the run taught to a notes file instead, one dated line per point, in the narrowest scope that
fits:

- **local** — `.agents/skill-notes/repair-agent-host.local.md`, kept out of git (add `*.local.md` to
  that folder's ignore rules if it is not there yet). The default.
- **repo** — `.agents/skill-notes/repair-agent-host.md`, committed, read by everyone who works in this
  repository.
- **user** — `~/.agents/skill-notes/repair-agent-host.md`, true for you in every project.

Then ask the user whether a note should go back into the skill itself, through the flow they use for it
— an issue, a pull request, an edit in the plugin's own repository. When you do not know that flow, ask.

What is worth noting, in this skill:

- **Step 3 has never failed.** Every criterion in it was already true the first time it was written, which
  makes running it feel like verification while proving nothing. Test one of them against the state it is
  supposed to reject — remove the token, or set `allowSignedOutWhenUsable` to `false` — and record which
  log line the host writes, because the table in Step 0 currently guesses at that row.
- **The Linux and musl branches of `_paths.sh` and the target computation rest on reading the host's code,
  never on a run.** The first repair on a Linux machine is the evidence they wait for.
- **The Codex half is installed but never loaded.** A Codex install has been carried out against a
  throwaway user-data directory and matched the Claude one step for step, so `product.json`'s symmetry
  holds that far. What no run has done is start a Codex session from the cache it produced.

Verified against: VS Code 1.137.0 (stable, macOS arm64), Claude Agent SDK 0.3.258, `product.json`
`agentSdks` shape as of 2026-09-10.
