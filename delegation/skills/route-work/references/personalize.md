# Tuning the routing table to your own work

The table in `SKILL.md` is a starting recommendation. These three modes replace its defaults with what your
own sessions show. Keep your tuned table and your register in your own repository — for example beside
this skill, or in a rule file your sessions load — and point the table's rows at the register rows behind
them.

## Measure — how your delegations actually chose their model

```sh
node <this skill>/scripts/measure.js --root . --days 60
```

Run it from the project whose sessions you want to read. It prints, for each kind of delegation, the model
that was asked for, the model that actually ran, the effort it ran at, how many, and their average tokens
and wall time; then an audit of the `[route-work]` lines — how many delegations a line covered, and every
case where the line and what ran disagree. `--scope all` reads every project on the machine.

**A result of `delegations examined: 0` means one of two things.** Either no session in the window
delegated anything, or the script is not reading your sessions. Tell them apart: Claude Code keeps each
project's transcripts in a folder under `~/.claude/projects/` named after the project's path with `/` and
`.` replaced by `-`, and the default scope reads only the folder matching `--root` and the folders beneath
it. If that folder is missing, or holds no `.jsonl` file from the window, the zero is about the path, not
about your delegations — pass the right `--root`, widen `--days`, or use `--scope all`.

Read three things in it before changing anything:

- **`asked=inherit`** — a delegation that named no model and ran on the session's. The table cannot have
  chosen it.
- **Where `asked` and `ran` differ** — an ask that was overridden, which nothing else reports.
- **The effort that ran** — an `Agent` call cannot carry one, so the transcript's value is the truth.

## Record — one row for every delegation you verified

Append a row whenever you verify a delegation's result, not only when it surprised you — a row that reads
"held, as expected" is still evidence, and a register that only ever records surprises is a sample biased
toward failure. Keep a register table with these columns:

| Date | Shape | Class | Asked | What happened | How it was verified |
|---|---|---|---|---|---|

**"How it was verified" is the column that makes a row evidence.** A row whose outcome was judged from the
agent's own summary is not evidence — rerun the gate, open the cited lines, read the diff. A delegation
nobody verified is recorded with its outcome as `?`, and `?` rows never move a score.

For a real comparison, pair the arms: write the tasks and their answer keys first, run each model on the
same tasks in fresh sessions, and judge blind to the arm.

## Update — move a row only when the number says so

For each `(model, effort, shape)` cell, compute over its verified rows:

```text
decayed_wins = Σ outcome_i · 0.5 ^ (age_days_i / HALF_LIFE)
decayed_n    = Σ           0.5 ^ (age_days_i / HALF_LIFE)
score        = (decayed_wins + K · prior) / (decayed_n + K)

outcome_i   1 if the delegation held (verified), 0 if it failed; ? excluded
prior       the cell's starting belief — use the shipped table: 0.8 for the row it recommends, 0.5 otherwise
HALF_LIFE   45 days
K           3 — the prior is worth about three observations
```

With no rows, the score is the prior, so the shipped table decides. As verified rows accumulate they
outweigh it, and old ones fade. Move a row when another cell's score passes the current one, and replace
its `basis` — `shipped default` in the table you started from — with your own evidence and the register
dates behind it, for example `own: 6/6 verified, 2026-10`.

Two failure shapes decide the lever once scores are close:

- a cheaper model **failed on reasoning** → move the row to the next model up, never to more effort on the
  same model;
- an expensive model was **only slow or only verbose** → drop its effort one level first, and change the
  model only if the score then drops.

Re-run `measure` after the next few weeks of work: a row that reads better and measures the same has not
been fixed.
