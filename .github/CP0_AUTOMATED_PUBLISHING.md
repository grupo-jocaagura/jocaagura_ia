# CP-0: Automated publishing trigger discovery

Status: **SERVICE ACCEPTANCE VERIFIED — final pub.dev audit attribution pending.**

The real 0.1.0 release succeeded via tag-ref workflow dispatch. See the
[recorded evidence](evidence/cp0-0.1.0.json) and the successful retry below.
Post-merge orchestration remains unimplemented; historical pending/failure
sections below describe earlier checkpoints, not the current upload result.

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
| `sub` | Record the actual subject; this repository requires the immutable owner/repository IDs and tag, as confirmed below |
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

## First live attempt and immutable-subject correction

On 2026-09-13 UTC, the maintainer explicitly confirmed the real 0.1.0 upload.
[Run 34733145670](https://github.com/grupo-jocaagura/jocaagura_ia/actions/runs/34733145670)
used `workflow_dispatch` on `v0.1.0` at
`8761a8e55bee5fddf64ecffb219aa7e48ff294c4`. Preflight, dry run and full CI passed.
The official setup-dart action obtained an OIDC token, but our local claims check
failed. The actual upload step was **skipped**; pub.dev still had no 0.1.0 version.
This is not a pub.dev authorization rejection and does not pass CP-0.

The original verifier incorrectly required the legacy name-only `sub`. GitHub's
read-only `GET /repos/grupo-jocaagura/jocaagura_ia/actions/oidc/customization/sub`
confirmed this actual repository configuration:

```json
{
  "use_default": true,
  "use_immutable_subject": true,
  "sub_claim_prefix": "repo:grupo-jocaagura@193098028/jocaagura_ia@1367412398"
}
```

The repository was created on 2026-09-12. GitHub now defaults new repositories to
immutable subjects; see [the official change](https://github.blog/changelog/2026-04-23-immutable-subject-claims-for-github-actions-oidc-tokens/)
and [OIDC reference](https://docs.github.com/en/actions/reference/security/oidc).
The expected tag subject is therefore:
`repo:grupo-jocaagura@193098028/jocaagura_ia@1367412398:ref:refs/tags/v0.1.0`.
This value is derived from the actual configuration; the failed run did not emit
its JWT claims because validation precedes recording. The old generic diagnostic
cannot prove which field failed first, but the incompatible subject check is
confirmed and must be corrected before any retry.

The corrected verifier binds both numeric IDs, repository names and the exact
tag subject; it does not change GitHub settings or allow the legacy subject for
this repository. A dedicated exception now reports only the failed field name,
never the JWT or received value. Tests cover the confirmed immutable prefix,
wrong IDs, wrong refs, rejected legacy subjects and token-free CLI diagnostics.

**Recovery remains pending.** The existing tag was not moved or deleted and
still contains the old verifier. Re-running that tag cannot load this correction.
A replacement of this still-unpublished tag would require an explicit maintainer
exception to the documented tag-immutability rule after reviewing this fix,
integration through develop -> master and successful CI. Do not change the tag,
downgrade OIDC configuration or retry publication automatically as part of this PR.
Record any approved recovery and both old/new SHAs before attempting the upload.

## Successful authorized recovery and real publication

The maintainer explicitly authorized integrating the fix through develop -> master,
replacing only the still-unpublished 0.1.0 tag, recording both SHAs and retrying.
PR #15 merged into develop and PR #16 into master. All required checks passed.
Only excluded .github tooling differs between the old and corrected commits.

- Old tag commit: `8761a8e55bee5fddf64ecffb219aa7e48ff294c4`.
- Corrected and published commit: `d60302c7ad0f65b25356fb02516fb899597e42aa`.
- The old tag was removed using an exact-SHA lease after confirming that 0.1.0
  was still absent from pub.dev. No other tag changed.
- [Preparation run 34733816592](https://github.com/grupo-jocaagura/jocaagura_ia/actions/runs/34733816592)
  recreated the tag with GITHUB_TOKEN; its publication job was skipped.
- [Publication run 34733859146](https://github.com/grupo-jocaagura/jocaagura_ia/actions/runs/34733859146)
  ran on `ref=v0.1.0`, passed full CI, recorded the expected immutable OIDC
  subject, and received pub.dev's successful upload response. The run succeeded.
- The public API confirms 0.1.0 was published at `2026-09-13T02:48:26.101144Z`.
  Archive SHA-256: `6c5f790988184deaded67310c2ea5ef8fda6d64bdad1dd2b3e5119df89ce57f3`.
- Independent verification downloaded the published archive, checked its hash,
  and confirmed all **39 files** byte-match the published commit. The Dartdoc
  interval correction is present; repository automation and companion packages
  are excluded. This is a real publication, not a dry run or duplicate skip.
- [GitHub Release v0.1.0](https://github.com/grupo-jocaagura/jocaagura_ia/releases/tag/v0.1.0)
  now contains the consolidated release notes.

The exact observed claims, saved configuration and run URLs are preserved in
[evidence/cp0-0.1.0.json](evidence/cp0-0.1.0.json); no JWT is included.
This demonstrates live pub.dev acceptance of workflow_dispatch on a matching tag
created by GITHUB_TOKEN, without alternate credentials or an external service.
The available browser cannot read the authenticated pub.dev audit log; its
attribution to run 34733859146 was requested from the maintainer to complete the
agreed evidence record. Automatic post-merge orchestration remains a subsequent
implementation step. Never re-upload 0.1.0 or move its now-published tag.
