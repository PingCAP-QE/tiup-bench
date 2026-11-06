# Releasing TiUP Bench

The release workflow builds all four supported platforms without signing secrets,
then passes their archives and SHA-256 files to a separate publisher job. The
publisher requires the `tiup-production` GitHub Environment and a successful build
matrix. It does not check out the repository, extract the bench archives, or run
their contents. Publishing is serialized across releases and platforms.

Only a published, non-draft, non-prerelease GitHub release with a tag of the form
`vMAJOR.MINOR.PATCH` is accepted. Checkout uses the release event's `github.sha`,
not a user-supplied ref or a subsequently moved tag. Pushes, scheduled runs and
manual dispatches are no longer release entry points. Nightly and staging were
removed to reduce signing access in this previously inactive workflow.

## Required administrator setup

Keep the workflow disabled until all of the following are complete. Adding
`environment:` in YAML does **not** configure its approval policy: GitHub can
create a referenced Environment without protection rules.

1. Create `tiup-production`. Require trusted release reviewers, prevent self-review,
   and disable administrator bypass of deployment protection rules where supported.
   Ensure the repository's GitHub plan supports these protections.
2. Select deployment **tags** matching the approved release naming policy (for
   example `v*`); do not allow branches. Do not use "Protected branches only" as a
   substitute, especially when the repository has no branch protection rules.
3. Protect the default branch and release tags with rulesets. Require review of
   workflow, dependency lock and packaging changes; restrict release tag creation,
   updates and deletion to release maintainers. Review the event commit and all
   four packages before approving a deployment. Environment approval does not
   prove that a tag points to reviewed source.
4. Put the base64-encoded TiUP private-key JSON in the Environment secret
   `TIUP_PRODUCTION_SIGNING_KEY`. Do not create this name at repository or
   organization scope. This is deliberately different from the legacy
   `TIUP_COMP_KEY_PINGCAP` name, so the patched workflow cannot fall back to that
   old repository secret. Remove the old repository/organization signing secret
   and revoke its availability to this repository. Historical workflow revisions
   can still reference legacy secrets until access is removed.
5. Check the legacy key's actual owner and scope, assess whether rotation is
   needed, and provision a key/owner restricted to `bench` if the mirror supports
   it. Do not reuse a production signing key for staging. The workflow cannot
   reduce the mirror-side authority of an existing key.
6. Set Environment variable `TIUP_PRODUCTION_MIRROR` to the administrator-verified
   production HTTPS mirror URL. There is no default mirror or staging fallback.
   After configuring and checking the protections above, set Environment variable
   `TIUP_PRODUCTION_READY` to the exact string `true`. Neither variable should be
   set at repository or organization scope. The ready flag is an explicit setup
   acknowledgement, not an API check of the Environment's protection rules.
7. Review the code and validation results, then enable the workflow separately.
   Publishing a real release and approving its deployment are production actions.

No repository settings, secrets or mirror permissions are changed by this code.
The approval and mirror publish paths require a separately authorized real run.
An empty ready flag, missing/invalid mirror URL, missing key, unknown channel or
invalid release tag causes failure before signing. Private-key material is injected
only into the signing step, written with owner-only permissions, removed by an
EXIT trap, and covered by an `always()` cleanup step. Artifact downloads and TiUP
installation happen before the key is loaded; GitHub release uploads happen after
cleanup. Forced runner termination may prevent cleanup from running, so publishing
uses an ephemeral GitHub-hosted runner.

Artifacts are restricted to the current workflow run and attempt. All four
archives must be present and match their checksums; unexpected files are rejected.
If a build attempt partially fails, rerun **all jobs** so that the new attempt has a
complete set. Build-generated checksums detect transfer corruption; they do not
replace source review or Environment approval. A mirror failure after some
platforms publish can leave a partial release; inspect mirror state before retrying.

## Local packaging and dependency updates

`make build` builds the wrapper. `make package` also downloads and verifies the
locked go-tpc and go-ycsb binaries and produces a tarball. It requires Go, Bash,
curl, SHA-256 tooling (`sha256sum` or `shasum`) and GNU tar. On macOS, install GNU
tar as `gtar`; the Makefile selects it automatically. Set `GOOS`, `GOARCH`, and
`REL_VER` as needed, for example:

```sh
make package GOOS=linux GOARCH=arm64 REL_VER=v1.2.3
```

Only linux/darwin on amd64/arm64 are supported. `TPC_URL` and `YCSB_URL` overrides
were removed. Downloads use HTTPS, fail on HTTP errors, and are checked against
`tools/release/dependencies.sha256` before either archive is extracted. The script
reads only the expected binary from each archive and never runs downloaded code.

The checked-in SHA-256 values were verified on 2026-11-06 against downloaded
release assets, GitHub's release-asset SHA-256 metadata, and these upstream files:

| Dependency | Locked release | Upstream checksum source |
| --- | --- | --- |
| go-tpc | [v1.0.12](https://github.com/pingcap/go-tpc/releases/tag/v1.0.12) | `checksums.txt` in the release |
| go-ycsb | [v1.0.3](https://github.com/pingcap/go-ycsb/releases/tag/v1.0.3) | Each platform's `.tar.gz.sha256` asset |
| TiUP publisher | [v1.17.1](https://github.com/pingcap/tiup/releases/tag/v1.17.1) | GitHub asset SHA-256 for `tiup-v1.17.1-linux-amd64.tar.gz` |

TiUP's archive digest is pinned directly in the workflow because the publisher
never checks out repository files. Its `bin/tiup` and bundled `bin/root.json` are
extracted only after verification. The bundled root is passed explicitly to
`tiup mirror set`. These hashes establish the reviewed bytes; upstream checksum
files and GitHub metadata share the upstream project's trust boundary and are
not independent provenance attestations.

To update dependencies, choose explicit release versions, download all four
platform archives, compare their hashes with upstream published SHA-256 values,
and review the changes. Update the versioned URLs in the download script and the
lock file together. For TiUP, update the URL, filename and digest in the workflow.
Never fetch an expected checksum dynamically during a release. Verify action
commit pins against their commented version tags when updating them.

Before merging a release change, run `actionlint`, parse the YAML, run `make build`
and `make package`, and confirm that packaging fails after changing archive bytes
or an expected checksum. Do not commit validation downloads, credentials, or
handoff notes.
