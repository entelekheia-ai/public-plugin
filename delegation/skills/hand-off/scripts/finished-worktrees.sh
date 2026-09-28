#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# bash, not sh: the worktree list is read NUL-separated (`read -d ''`) so a path may hold any byte.
[ -n "${BASH_VERSION:-}" ] || { echo "finished-worktrees: needs bash — run it as: bash finished-worktrees.sh <repo>" >&2; exit 2; }
# finished-worktrees.sh — which worktrees of a repository are done and can be removed. Read-only: it
# fetches and prints, and removes nothing, because removing a worktree is a decision for whoever is at
# the keyboard.
#
#   sh finished-worktrees.sh <repo>
#
# One line per worktree other than the main one (always the first entry `git worktree list` reports —
# skipped by position, so this works whether <repo> is the main checkout, a linked worktree, or a bare
# repository, whose own entry there is bare rather than a checkout):
#   merged            <path> <branch>  every commit on branch is on the default branch already (a merged
#                                      PR), tree clean
#   leftover          <path> <branch>  a worktree-agent-* branch with nothing the default branch lacks, or
#                                      a detached HEAD whose commit some remote-tracking branch (or the
#                                      default branch itself) already contains — nothing there is unique
#   detached-unpushed <path> <branch>  a detached HEAD holding a commit no remote-tracking or default
#                                      branch contains — not safe to remove
#   dirty             <path> <branch>  uncommitted or untracked files — look before removing
#   unreadable        <path> <branch>  `git status` itself failed (permissions, a missing directory) —
#                                      not safe to remove
#   open              <path> <branch>  commits not on the default branch — still in flight (including a
#                                      worktree-agent-* branch that has grown real commits of its own, and
#                                      any branch whose comparison against the default itself failed —
#                                      never read as "merged")
# A squash-merged branch reads as `open`, because its commits never reach the default branch by hash. A
# branch created and never committed to reads as `merged`, because it has nothing the default branch lacks.
#
# With an `origin` remote, fetches it and resolves ONLY among origin's own refs — `refs/remotes/origin/HEAD`
# (its symbolic-ref target), then `refs/remotes/origin/main`, then `refs/remotes/origin/master` — every one
# compared by its full refname, never a short name a same-named tag or local branch could shadow. With no
# origin, falls back to `refs/heads/main`, then `refs/heads/master`, then the main checkout's own current
# branch, and never falls to any of those while an origin exists: a repository whose origin's default
# branch is neither `main` nor `master`, and that never set `origin/HEAD`, has no ref this script will
# guess at — it refuses instead of comparing against a stale local branch. One line to stderr says which
# ref was used when there was no origin to explain it; a main checkout on a detached HEAD with no origin,
# or an origin with nothing this script can resolve, refuses with a one-line message instead of git's own
# raw error.
set -eu

repo_arg=${1:?usage: finished-worktrees.sh <repo>}
# A bare repository has no top level to resolve — `--show-toplevel` refuses there ("must be run in a work
# tree") — so its own directory is the anchor. Mirrors prepare-worktree.sh's own copy of this check;
# kept identical by hand in both scripts, not factored into a shared file.
if [ "$(git -C "$repo_arg" rev-parse --is-bare-repository 2>/dev/null)" = true ]; then
  repo=$(cd "$repo_arg" && pwd)
else
  repo=$(cd "$repo_arg" && git rev-parse --show-toplevel)
fi

# Prints the repository's default ref, as a full refname, on stdout and returns 0, or prints nothing and
# returns 1 when none resolves. Every step is its own guarded `if`, so a failure here never trips this
# script's own `set -e` — a failing command that is itself the condition of an `if` does not. Kept
# identical to prepare-worktree.sh's own copy: no shared lib file, so each script stays runnable on its
# own; a change to one must be copied into the other by hand.
resolve_default() {
  r=$1
  if git -C "$r" remote get-url origin >/dev/null 2>&1; then
    if ref=$(git -C "$r" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null); then
      printf '%s\n' "$ref"
      return 0
    fi
    for cand in refs/remotes/origin/main refs/remotes/origin/master; do
      if git -C "$r" rev-parse --verify -q "$cand^{commit}" >/dev/null 2>&1; then
        printf '%s\n' "$cand"
        return 0
      fi
    done
    return 1 # origin exists but none of its own refs resolve — never fall back to a local branch
  fi
  for cand in refs/heads/main refs/heads/master; do
    if git -C "$r" rev-parse --verify -q "$cand^{commit}" >/dev/null 2>&1; then
      printf '%s\n' "$cand"
      return 0
    fi
  done
  if ref=$(git -C "$r" symbolic-ref HEAD 2>/dev/null); then
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
  echo "finished-worktrees: could not resolve a default branch — no origin/HEAD, no origin/main, no origin/master, and (with no origin) neither refs/heads/main, refs/heads/master nor the main checkout's own branch (detached HEAD). Check out a branch in $repo, or set origin/HEAD, and retry." >&2
  exit 1
fi
if [ "$had_origin" = 0 ]; then
  echo "finished-worktrees: no origin remote — comparing against local $default" >&2
fi
if ! git -C "$repo" rev-parse --verify -q "$default^{commit}" >/dev/null 2>&1; then
  echo "finished-worktrees: the resolved default ref '$default' does not exist in $repo — nothing to compare against" >&2
  exit 1
fi

# `-z`: every field is NUL-terminated, including the blank line between worktrees, so a path holding a
# literal tab or newline is never split — NUL is the one byte no path can contain. The first record `git
# worktree list` reports is always the main worktree (a checkout, or, for a bare repository, its own bare
# entry); it is always skipped, so this reads correctly whether <repo> is the main checkout, a linked
# worktree, or the bare repository itself.
git -C "$repo" worktree list --porcelain -z |
  {
    first=1
    path=""
    branch=""
    while IFS= read -r -d '' field; do
      if [ -z "$field" ]; then
        if [ "$first" = 1 ]; then
          first=0
        elif [ -n "$path" ]; then
          if ! st=$(git -C "$path" status --porcelain 2>/dev/null); then
            echo "unreadable        $path $branch"
          elif [ -n "$st" ]; then
            echo "dirty             $path $branch"
          elif [ "$branch" = "(detached)" ]; then
            head=$(git -C "$path" rev-parse HEAD 2>/dev/null || true)
            if [ -n "$head" ] && { [ -n "$(git -C "$repo" branch -r --contains "$head" 2>/dev/null)" ] ||
              git -C "$repo" merge-base --is-ancestor "$head" "$default" 2>/dev/null; }; then
              echo "leftover          $path $branch"
            else
              echo "detached-unpushed $path $branch"
            fi
          else
            if out=$(git -C "$repo" rev-list "$default..refs/heads/$branch" --); then
              [ -z "$out" ] && unique=0 || unique=1
            else
              unique=1 # rev-list itself failed — never read a failure as "merged"
            fi
            if [ "$unique" = 0 ]; then
              if [ "${branch#worktree-agent-}" != "$branch" ]; then
                echo "leftover          $path $branch"
              else
                echo "merged            $path $branch"
              fi
            else
              echo "open              $path $branch"
            fi
          fi
        fi
        path=""
        branch=""
        continue
      fi
      case "$field" in
        "worktree "*) path=${field#worktree } ;;
        "branch "*)
          branch=${field#branch }
          branch=${branch#refs/heads/}
          ;;
        detached) branch="(detached)" ;;
      esac
    done
  }
