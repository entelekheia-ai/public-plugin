# publishing

**Take the skills, subagents or rules you wrote for your own setup and make them publishable.**
`publishing` walks the whole path: inventory what you have, compare each item against what is already
public, audit it for private data and internal conventions, triage the hits with you, generalize the
text, verify it mechanically and with a blind review, and release it into a plugin catalog.

## Skills

| Command | Fires when |
|---|---|
| `/publishing:publish` | Deciding which of your own skills or agents are worth sharing; a private skill is about to become public. |

## Agents

| Agent | What it does |
|---|---|
| `publishing:extraction-auditor` | Reads every file of a skill, subagent or rule being considered for publication and reports, with `file:line` and quoted text, private data, dependencies a stranger will not have, internal evidence, and overlap with a public equivalent — read-only. |
| `publishing:edit-applier` | Applies an already-decided edit list (numbered replacements, deletions, insertions with exact old and new text) to files, verbatim, and reports per edit whether it applied. |

## Install

```sh
claude plugin install publishing@entelekheia
```
