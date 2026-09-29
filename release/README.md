# release

**Release channels for npm packages.** `release` installs a stable-and-beta channel policy into a
repository, runs the promotion ceremony that turns an accumulated beta into the next stable release, and
takes a repository that has never published to publishing itself from CI through npm trusted publishing.

## Skills

| Command | Fires when |
|---|---|
| `/release:release-channels-adopt` | Bringing a repository onto a stable+beta channel policy, or repairing a partial adoption. |
| `/release:release-promote` | A milestone means the accumulated beta channel should become the next stable release. Not for plain fixes — patches go straight to stable by policy. |
| `/release:release-first-publish` | A repository's packages have never reached a registry, a publish fails with a 404, `ENEEDAUTH` or an unexplained OIDC permission error, a monorepo's packages must reach npm in order, or a repository still publishes with a stored `NPM_TOKEN` and should not. |

## Requirements

An npm package repository on GitHub, and `node` and `npm` for `publish-order.mjs` and the publish loop.
[Changesets](https://github.com/changesets/changesets) is optional: `release-channels-adopt` sets it up, and
`release-first-publish` has a by-hand path for a repository that versions without it.

## Install

```sh
claude plugin install release@entelekheia
```
