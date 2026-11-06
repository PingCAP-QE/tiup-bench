# Releasing TiUP Bench

The workflow accepts published, non-prerelease releases tagged `vMAJOR.MINOR.PATCH`
and checks out the event commit. Push, manual dispatch and scheduled publishing
are removed. The four-platform build has no signing secrets. A separate publisher
requires a successful build and the `tiup-production` Environment; it verifies
artifacts from the current run/attempt without executing their contents.

## Existing configuration

The publisher reuses the existing repository secrets:

- `TIUP_COMP_KEY_PINGCAP`: base64-encoded TiUP private-key JSON.
- `TIUP_SERVER_PROD`: production mirror address. An empty value fails; there is no
  fallback to another mirror.

No new secrets or variables are required. `TIUP_SERVER_STAGING` is unused because
this workflow now has only a production channel.

Before enabling the workflow, configure `tiup-production` with required reviewers,
prevent self-review, disable administrator bypass, and allow only approved release
tags (for example `v*`). Protect `master` and release tags against unreviewed changes.
Declaring the Environment in YAML does not create its approval rules.

The signing key is loaded only in the publishing step, written with mode 0600,
and deleted by an EXIT trap and an `always()` cleanup step. GitHub release assets
are uploaded after cleanup. Keeping the key at repository scope means other
workflows can still reference it; this Environment gates this publisher only.

## Packaging and dependency pins

`make package` requires Go, Bash, curl, `sha256sum` or `shasum`, and GNU tar (`gtar`
on macOS, selected automatically). `GOOS`, `GOARCH` and `REL_VER` remain configurable.
Both dependency archives must match the checked-in SHA-256 values before extraction.
The download script reads only the expected binaries and never runs them.

| Dependency | Version | SHA-256 source verified on 2026-11-06 |
| --- | --- | --- |
| [go-tpc](https://github.com/pingcap/go-tpc/releases/tag/v1.0.12) | v1.0.12 | Release `checksums.txt` and GitHub asset digests, all four platforms |
| [go-ycsb](https://github.com/pingcap/go-ycsb/releases/tag/v1.0.3) | v1.0.3 | Release `.sha256` files and GitHub asset digests, all four platforms |
| [TiUP publisher](https://github.com/pingcap/tiup/releases/tag/v1.17.1) | v1.17.1 | GitHub asset digest for the Linux amd64 archive |

Dependency hashes are stored in `tools/release/dependencies.sha256`; the publisher
archive hash is in the workflow. TiUP and its bundled root are verified together.
To update a pin, review the versioned URL and downloaded bytes against upstream
SHA-256 values, then change the URL and checked-in digest together.

Validate changes with `actionlint`, `make build`, `make package`, and an archive
or checksum tampering check. After a partial build failure, rerun all jobs to
produce a complete set for the new attempt. Mirror publishing is sequential and
can leave a partial release on failure; inspect mirror state before retrying.
