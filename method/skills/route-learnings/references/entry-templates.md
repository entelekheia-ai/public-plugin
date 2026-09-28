# Entry templates

Two proposed shapes, one per destination this skill writes to directly. Each carries exactly the fields
that destination's admission test asks for; copy one, fill it, and keep the headings. If your repository
already has its own template for either kind, use that one instead.

## A durable fact — `docs/learnings/<slug>.md`

The slug is the claim, shortened: `npm-oidc-covers-publish-only`, not `npm-auth`.

```markdown
---
scope: <what this is true of — a tool@version, a library, a service, a habit>
attempted: YYYY-MM-DD
---

# <The fact, stated as a claim someone could check>

<What is true, in one or two sentences.>

## Evidence

<The command and its output, the doc and its version, or the run that showed it.>

## Where it applies

<When someone would otherwise get this wrong, and what they should do instead.>

This records what was known on the `attempted:` date, not a current truth. Re-verify it when `scope:`
moves to a new version.
```

## A trap or a debt — `docs/learnings/traps/<slug>.md`

The slug names what happens: `ci-cache-hides-lockfile-drift`.

```markdown
---
path: <the file, folder or package where someone meets this again>
kind: trap | debt
date: YYYY-MM-DD
---

# <What happens there, in one line>

## What was attempted

<The change or command, as it was run.>

## What happened

<The observed result, including anything that looked like success.>

## Mechanism

<Why it happens — or "not established", which is better than a guess.>

## Evidence

<The output, the diff, the commit, the issue.>
```

`kind: trap` says *do not do this again*; `kind: debt` says *we know, and we chose to live with it* — the
user chooses which. There is no `status:` field: an attempt that was later reverted and worked says so in
its own sections.
