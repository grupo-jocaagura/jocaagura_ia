# CP-0: Automated publishing trigger discovery

Status: **PENDING — automatic post-merge publishing is not implemented.**

Issue: https://github.com/grupo-jocaagura/jocaagura_ia/issues/8

## Evidence collected on 2026-09-12 (America/Bogota)

- The live [package API](https://pub.dev/api/packages/jocaagura_ia) reports the
  manually published `jocaagura_ia` version **0.0.1**. `0.1.0` is the next
  candidate, not the bootstrap publication.
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
- The package Admin page required Google sign-in in the available browser;
  its actual publishing configuration could not be inspected. No GitHub OIDC
  run against this package has been performed in this checkpoint.

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
| pub.dev package | `jocaagura_ia` |
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
   a throwaway version or accidentally publish the 0.1.0 candidate as a probe.
   If safe authorization-only verification is unavailable, leave CP-0 pending
   until a maintainer agrees on the real release verification procedure.
4. Only after this checkpoint passes may automatic post-merge orchestration be
   refined and implemented. The dispatch workflow must also be present on the
   repository default branch, currently `develop`, and on the target tag.

## Fail-closed decision

While CP-0 is pending, or if pub.dev rejects this path, the publisher accepts
only a human-pushed version tag. No workflow creates tags or dispatches the
publisher after a merge. There is no variable that bypasses this checkpoint.
Do not add a PAT, service account, external service or alternate credential.
The fallback is an explicitly human-pushed release tag until the constraint
is revised. Follow the procedure in [CI_CD.md](CI_CD.md).