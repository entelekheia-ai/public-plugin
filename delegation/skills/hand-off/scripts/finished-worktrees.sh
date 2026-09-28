#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# finished-worktrees.sh — which worktrees of a repository are done and can be removed. Read-only: it
# fetches and prints, and removes nothing, because removing a worktree is a decision for whoever is at
# the keyboard.
#
#   sh finished-worktrees.sh <repo>
#
# One line per worktree other than the main checkout:
#   merged            <path> <branch>  the branch's commits are all in the default branch (a merged PR),
#                                      tree clean
#   leftover          <path> <branch>  an isolated subagent's worktree (branch worktree-agent-*, or a
#                                      detached HEAD whose commit some other branch already contains),
#                                      tree clean
#   detached-unpushed <path> <branch>  a detached HEAD holding a commit no local or remote-tracking
#                                      branch contains — not safe to remove
#   dirty             <path> <branch>  uncommitted or untracked files — look before removing
#   open              <path> <branch>  commits not in the default branch — still in flight
# A squash-merged branch reads as `open`, because its commits never reach the default branch by hash. A
# branch created and never committed to reads as `merged`, because it has nothing the default branch lacks.
#
# With an `origin` remote, fetches it and compares against origin's own default branch
# (refs/remotes/origin/HEAD, falling back to origin/main then origin/master when the remote never set
# HEAD — a remote added by hand, rather than by `git clone`, leaves it unset). With no `origin` remote —
# the way prepare-worktree.sh checks `git remote get-url origin` first — nothing is fetched, and the
# comparison falls back to the main checkout's own current branch, with one line to stderr saying so. A
# main checkout on a detached HEAD with no origin has nothing to fall back to, and the script refuses with
# a one-line message instead of git's own raw error.
set -eu

repo=$(cd "${1:?usage: finished-worktrees.sh <repo>}" && git rev-parse --show-toplevel)

# Prints the repository's default branch/ref on stdout and returns 0, or prints nothing and returns 1
# when none resolves. Every step is its own guarded `if`, so a failure here never trips this script's own
# `set -e` — a failing command that is itself the condition of an `if` does not.
resolve_default() {
  r=$1
  if git -C "$r" remote get-url origin >/dev/null 2>&1; then
    if ref=$(git -C "$r" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null); then
      printf '%s\n' "$ref"
      return 0
    fi
    for cand in origin/main origin/master; do
      if git -C "$r" rev-parse --verify -q "$cand^{commit}" >/dev/null 2>&1; then
        printf '%s\n' "$cand"
        return 0
      fi
    done
  fi
  for cand in main master; do
    if git -C "$r" rev-parse --verify -q "refs/heads/$cand" >/dev/null 2>&1; then
      printf '%s\n' "$cand"
      return 0
    fi
  done
  if ref=$(git -C "$r" symbolic-ref --short HEAD 2>/dev/null); then
    printf '%s\n' "$ref"
    return 0
  fi
  return 1
}

if git -C "$repo" remote get-url origin >/dev/null 2>&1; then
  git -C "$repo" fetch -q origin
  had_origin=1
else
  had_origin=0
fi

if ! default=$(resolve_default "$repo"); then
  echo "finished-worktrees: could not resolve a default branch — no origin/HEAD, no origin/main, no origin/master, and the main checkout has no branch of its own (detached HEAD). Check out a branch in $repo, or set origin/HEAD, and retry." >&2
  exit 1
fi
if [ "$had_origin" = 0 ]; then
  echo "finished-worktrees: no origin remote — comparing against local $default" >&2
fi
if ! git -C "$repo" rev-parse --verify -q "$default^{commit}" >/dev/null 2>&1; then
  echo "finished-worktrees: the resolved default ref '$default' does not exist in $repo — nothing to compare against" >&2
  exit 1
fi

# Splits only on "worktree " / "branch " / "detached", never on the path itself (a path may hold a
# space), and joins path and branch with a tab so the `read` below can split safely on that alone.
git -C "$repo" worktree list --porcelain | awk '
  /^worktree / { p = $0; sub(/^worktree /, "", p) }
  /^branch /   { b = $0; sub(/^branch /, "", b); sub("refs/heads/", "", b); printf "%s\t%s\n", p, b }
  /^detached/  { printf "%s\t(detached)\n", p }
' |
  while IFS="$(printf '\t')" read -r path branch; do
    [ "$path" = "$repo" ] && continue
    if [ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]; then
      echo "dirty             $path $branch"
    elif [ "$branch" = "(detached)" ]; then
      head=$(git -C "$path" rev-parse HEAD 2>/dev/null || true)
      if [ -n "$head" ] && [ -n "$(git -C "$repo" branch --all --contains "$head" 2>/dev/null)" ]; then
        echo "leftover          $path $branch"
      else
        echo "detached-unpushed $path $branch"
      fi
    elif [ "${branch#worktree-agent-}" != "$branch" ]; then
      echo "leftover          $path $branch"
    elif [ -z "$(git -C "$repo" rev-list "$default..$branch")" ]; then
      echo "merged            $path $branch"
    else
      echo "open              $path $branch"
    fi
  done
