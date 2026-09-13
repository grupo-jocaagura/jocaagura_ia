# CP-0: Automated publishing trigger discovery

Status: **PENDING — package settings confirmed; live OIDC acceptance is still unverified.**

Issue: https://github.com/grupo-jocaagura/jocaagura_ia/issues/8

## Evidence collected on 2026-09-12 (America/Bogota)

- The live [package API](https://pub.dev/api/packages/jocaagura_ai) reports the
  manually published `jocaagura_ai` version **0.0.2** at initial discovery. This was the
  first manual publication, not an automated release. The corrected package URL is
  `https://pub.dev/packages/jocaagura_ai`; its score API reports **160/160**.
  The repository-mismatch report belongs to the different `jocaagura_ia` package.
- The [Dart publishing overview](https://dart.dev/tools/pub/automated-publishing)
  still describes publishing as requiring a tag-push trigger.
- [pub.dev issue 8507](https://github.com/dart-lang/pub-dev/issues/8507) contains
  maintainer confirmation of `workflow_dispatch` support. This is supporting
  evidence, not proof that this package is configured for it.
- The current upstream implementation at
  [`965acc0e4f3b75dd5d4f979eee269a52ad00594f`](https://github.com/dart-lang/pub-dev/blob/965acc0e4f3b75dd5d4f979eee269a52ad00594f/app/lib/package/backend.dart#L1675)
  checks `isWorkflowDispatchEventEnabled`, permits only `push` or
  `workflow_dispatch`, requires `ref_type == tag`, matches `refs/tags/` plus the
  configured version pattern, and checks the configured repository/environment.
  An upstream commit does not identify the exact deployed pub.dev revision.
- Initially, the available browser could not inspect the package Admin page.
  The maintainer subsequently supplied a screenshot and confirmed saving these
  settings: GitHub publishing enabled, repository `grupo-jocaagura/jocaagura_ia`,
  pattern `v{{version}}`, both `push` and `workflow_dispatch` enabled, and no
  required GitHub Environment. This is configuration evidence supplied by the
  maintainer, not evidence of service acceptance. No live OIDC upload has run.

## Reconciliation with develop 0.0.3

`origin/develop` at `f7620a5` prepares **0.0.3** and includes the ordered-content
work from PR #11. This PR preserves that version and its existing dated release
notes. Release automation and Dartdoc changes remain under `Unreleased` until
CI prepares the selected **minor** promotion, **0.0.3 -> 0.1.0**. It consolidates
all three preceding patches and the pending notes while retaining history.
The current PR does not manually preempt that CI version bump.

The live pub.dev API confirms 0.0.3 was published at
`2026-09-13T00:51:31.677313Z`, with archive SHA-256
`2f94390422e04451b5ed39fda681d2ac1e465ded8103da9b06313a6786cbff8c`.
The API confirms that patch must not be uploaded again. Under the clarified
release discipline, the publishing gate rejects patch versions altogether:
**Prepare promotion** must first produce the unpublished **0.1.0** candidate.
This read-only query establishes network access and version state, not OIDC
publishing permission. A skipped or rejected publisher cannot pass CP-0.

The next live verification must distinguish:

1. Version discipline: 0.0.3 is development history; CI prepares 0.1.0 with
   consolidated notes. Published versions must never be uploaded again.
2. GitHub OIDC identity: a real tag-ref run has the required event/ref claims.
3. pub.dev package authorization: the service accepts that identity for the
   package with its actual event/environment configuration.

Do not fabricate a tag-to-archive association, overwrite a version tag, or publish
an arbitrary version merely to complete the test. Leave CP-0 pending if the real
package-authorization step cannot be tested safely without a new release.

## Claims and settings to record for the live verification

| Item | Required value / evidence |
| --- | --- |
| GitHub dispatch API ref | `vX.Y.Z`, resolving to the intended immutable release commit |
| `iss` | `https://token.actions.githubusercontent.com` |
| `aud` | `https://pub.dev` (requested by the official setup-dart action) |
| `event_name` | `workflow_dispatch` |
| `ref_type` | `tag` |
| `ref` | `refs/tags/vX.Y.Z` |
| `repository` | `grupo-jocaagura/jocaagura_ia` |
| `sha` | Exact validated release commit; compare the tag's peeled commit |
| Identity binding | Record `repository_id`, `repository_owner_id` and `repository_owner`; pub.dev can lock numeric identities |
| `sub` | Record the actual subject; it normally represents the repository and tag, or the configured environment |
| Environment | Record whether required and the exact `environment` claim if enabled |
| Audit evidence | Record `run_id`, workflow URL, timestamp, event, ref and sanitized result |
| pub.dev package | `jocaagura_ai` |
| GitHub publishing | Enabled for the official repository |
| Tag pattern | `v{{version}}` |
| Event permission | `workflow_dispatch` explicitly enabled; keep `push` enabled for the human-tag fallback |

The official action requests the audience in
[setup-dart](https://github.com/dart-lang/setup-dart/blob/main/lib/main.dart).
Never print or store the complete JWT, bearer token or authorization headers.

## Completion requirements

1. Inspect and record the actual package Admin configuration, including any
   required GitHub Environment and the event toggles.
2. Verify dispatch against a tag with the real GitHub event/ref claims and
   pub.dev's package authorization. Record service evidence that distinguishes
   successful package authorization from merely obtaining a GitHub JWT.
3. A dry run, source inspection, mock or successful `setup-dart` step is not
   sufficient: these do not establish live package authorization. Do not upload
   a throwaway version, attempt to re-upload 0.0.3, or upload 0.1.0 as an
   accidental side effect of a probe.
   If safe authorization-only verification is unavailable, leave CP-0 pending
   until a maintainer agrees on the real release verification procedure.
4. Only after this checkpoint passes may automatic post-merge orchestration be
   refined and implemented. The dispatch workflow must also be present on the
   repository default branch, currently `develop`, and on the target tag.

## Fail-closed decision

While CP-0 is pending, the regular publisher accepts only a human-pushed
version tag. The separate, explicitly invoked CP-0 experiment below can create
one candidate tag and test dispatch publication. No workflow creates tags or
dispatches a publisher automatically after a merge. There is no variable that
marks CP-0 passed or enables post-merge publication.
Do not add a PAT, service account, external service or alternate credential.
The fallback is an explicitly human-pushed release tag until the constraint
is revised. Follow the procedure in [CI_CD.md](CI_CD.md).
## Controlled live experiment for 0.1.0

The `CP-0 controlled publication` workflow is a one-time manual experiment, not
post-merge orchestration. Configuration is now confirmed; **CP-0 remains pending**.
Preparing the experiment or obtaining an OIDC token does not complete CP-0.

1. Merge the experiment PR into `develop`, then a new official `develop -> master`
   PR. Both branches must contain `cp0_publication.yaml`. Use the **new** merged
   release commit, not the earlier PR #12 SHA (which lacks the experiment).
   Keep the candidate at 0.1.0: these changes affect excluded `.github/` tooling.
2. After required CI passes, review the exact commit, archive dry run, unpublished
   version and configuration. Explicitly agree to use the real 0.1.0 release as
   the authorization test before running the `publish` operation.
3. Dispatch `cp0_publication.yaml` on `develop` with `operation=prepare-tag` and
   `expected_sha=<new exact master merge SHA>`. It checks release provenance and
   creates `v0.1.0` with **GITHUB_TOKEN**. The token's tag push does not trigger the
   regular publisher. No workflow is dispatched by this step. Record its run URL
   as evidence of who created the tag. A same-SHA existing tag is only checked,
   not recreated; retain its original creation evidence. A conflicting tag fails.
4. Separately dispatch that workflow with **ref=v0.1.0**, `operation=publish`, the
   same `expected_sha`, and `confirmation=publish jocaagura_ai 0.1.0`.
   This is a REAL upload, not a dry run. It requires full CI, exact tag/SHA,
   current master, merged PR provenance and an unpublished version. It records
   only an allowlist of OIDC claims from the official setup-dart token, then
   publishes with that same identity. It uses no required Environment, matching
   the saved configuration. No PAT, persistent token or extra service is added.
5. Save both workflow URLs, the sanitized claims, successful upload step, public
   version/archive hash confirmation, and pub.dev Admin audit-log attribution.
   Only that combined service evidence can complete CP-0. Update this record and
   issue #8 before implementing any automatic post-merge orchestration.

If authorization is rejected, stop the experiment and leave post-merge publishing
unimplemented. Investigate the actual error; never weaken the configuration or
substitute credentials. If the upload succeeds but a later verification fails,
inspect the existing version and pub.dev audit log; do not rerun an upload or
claim an existing version proves this run's authorization. Preflight intentionally
fails for already-published 0.1.0. Do not delete, move or overwrite the tag to retry.
The regular human-pushed-tag workflow remains the fallback for an unpublished
release when CP-0 cannot be accepted; an existing experimental tag requires an
explicit recovery decision, not recreation. GitHub Release creation is a separate
follow-up after a verified experimental publication.
