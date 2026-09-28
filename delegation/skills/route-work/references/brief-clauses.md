# Clauses a brief needs, beyond the model

Read before writing any delegation. Each clause catches a failure that choosing a stronger model does not
prevent. Use the ones that fit the brief; the first is worth putting in every one.

## Let the agent contest the brief

Say: *if a claim in this brief is wrong against the real code, stop and say why with `file:line`* — and
name why it matters, because an agent that is merely permitted to disagree usually does not. **The brief
is the least-verified artifact in a delegation**: the plan was reviewed, the code goes through a gate, the
result goes through you, and the brief is written in one pass minutes before the call, by the one party
nothing checks.

## Make the agent cite what it read

When the work is "make this sentence true" — correcting a doc, a comment, a record — require the agent to
read the **code** before writing, and to return the `file:line` it read as a field of its result. Without
it, a corrector rewrites from the finding's own text and can write a new false claim while removing an old
one. Prefer this clause to a model upgrade for that kind of work.

## Read the declaration before calling something a defect

An agent that returns a verdict per item — a census, an inventory, a keep-or-convert sweep — must read the
declaration at each site before calling anything a defect, and quote it when its verdict contradicts it. A
`file:line` makes a claim cheap to check; it does nothing to stop a wrong judgement at a correct line.

## Verify a claim about a document before making it

If the brief says what a document contains, open the document and check first. A claim that is *almost*
true is the dangerous one: the agent either writes from it or spends a turn refuting it.

## State a scope as a limit

When the search is scoped to one repository or folder, say so as a limit, and require *"not found within
this scope"* rather than *"does not exist"*. The two read identically in a result and mean opposite
things; an absence found inside a boundary is evidence about the boundary.

## Name the risky part of a review

A review brief names what is dangerous in the diff — a wire contract, a public surface, a positional
argument. Reviews that found real defects were told where to look.

## Verbatim, for anything Haiku touches as prose

Say *move verbatim, do not paraphrase*, accept its data output by `diff`, and read any prose it produced in
full.

## Do the work, report only what happened

Tell an agent given work that it does the work itself and launches no subagent, and that it reports **only
what has already happened, never what is under way**. A report written in the present progressive is
indistinguishable from a finished one until you check the files. When you do check, check after the agent
you launched has stopped — an agent that delegated has stopped while its own child may still be running.

## Name read-only inputs by path

When the brief hands the agent a file to read — a fixture, a sample, an example — name that file read-only
**by its path**. A read-only clause scoped to a repository does not reach an input that lives elsewhere, and
an agent that needs a variant of it will overwrite the one it was given.

## Protect other people's uncommitted work

In a tree that holds someone else's uncommitted changes, forbid `git stash`, `git checkout` and
`git restore` by name, and say why. "Do not commit" does not cover them.

## Allow a refusal; forbid falsifying the input

When a gate, a build or a suite must go green, say that stopping red is an acceptable outcome and that
changing the input to satisfy the checker is not — and name the falsifications that would be tempting for
that gate. "Green" is a single legible target; when the checker is itself wrong, an agent that was never
told it could stop will make the input lie to it. Require the result to carry what it left failing.

## Leave work on disk

For anything long, say *write each piece to disk as you finish it, rather than holding work until the
end*. A delegation stopped by a usage limit or a timeout keeps only what it wrote.
