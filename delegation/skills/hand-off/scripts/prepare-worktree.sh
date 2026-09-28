#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# prepare-worktree.sh — a fresh worktree for one phase of delegated work, with dependencies installed.
#
#   sh prepare-worktree.sh <repo> <branch> [base]
#
# Fetches when the repository has an `origin` remote, creates <repo>/.claude/worktrees/<branch> on a new
# branch <branch> from [base] (default: origin's own default branch, or the main checkout's own current
# branch when there is no origin — see resolve_default below), and runs `npm ci` when the tree has a
# package-lock.json. Prints the worktree path on the last line. Refuses when the branch or the directory
# already exists, rather than reusing either: a branch checked out twice advances in both places. Refuses
# with "pass a base" when no default resolves and none was given.
set -eu

repo=${1:?usage: prepare-worktree.sh <repo> <branch> [base]}
branch=${2:?usage: prepare-worktree.sh <repo> <branch> [base]}

# A bare repository has no top level to resolve — `--show-toplevel` refuses there ("must be run in a work
# tree") — so its own directory is the anchor, and the worktree still lands under it.
if [ "$(git -C "$repo" rev-parse --is-bare-repository 2>/dev/null)" = true ]; then
  repo=$(cd "$repo" && pwd)
else
  repo=$(cd "$repo" && git rev-parse --show-toplevel)
fi
dir="$repo/.claude/worktrees/$branch"

# Prints the repository's default branch/ref on stdout and returns 0, or prints nothing and returns 1
# when none resolves. Every step is its own guarded `if`, so a failure here never trips this script's own
# `set -e` — a failing command that is itself the condition of an `if` does not. Kept identical to
# finished-worktrees.sh's own copy: no shared lib file, so each script stays runnable on its own.
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
fi

if [ -n "${3:-}" ]; then
  base=$3
elif base=$(resolve_default "$repo"); then
  :
else
  echo "prepare-worktree: could not resolve a default branch — no origin/HEAD, no origin/main, no origin/master, and the main checkout has no branch of its own (detached HEAD). Pass a base." >&2
  exit 1
fi

if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
  echo "prepare-worktree: branch $branch already exists — pick another name or reuse its worktree" >&2
  exit 1
fi
if [ -e "$dir" ]; then
  echo "prepare-worktree: $dir already exists" >&2
  exit 1
fi

git -C "$repo" worktree add -q -b "$branch" "$dir" "$base"
if [ -f "$dir/package-lock.json" ]; then
  (cd "$dir" && npm ci --no-audit --no-fund >/dev/null) || {
    echo "prepare-worktree: npm ci failed in $dir — the worktree exists without dependencies" >&2
    exit 1
  }
fi
echo "$dir"
