# jocaagura_ai CI/CD

The root package is the SDK-only `jocaagura_ai` domain. Its first manual pub.dev
release is **0.0.2**; develop is at **0.0.3**, and the selected **minor**
promotion will prepare **0.1.0** in CI. The integration consumer
`packages/jocaagura_ai_server` remains nonpublishable and excluded by `.pubignore`.
Release validation needs no running service, model weights or real inference.

## Continuous integration

`Dart CI` runs on branch pushes, PRs targeting `develop` or `master`, manual
runs, and reusable calls. It checks verified commit signatures, dependencies,
absence of committed overrides, formatting, strict analysis, release policy
and script tests, actionlint, Dart tests, and coverage. Existing checks apply
to both tracked packages. Coverage must be at least **95% per package and
combined**, without rounding; `COVERAGE_MIN` may only raise that threshold to
100. Reports are kept for 14 days. Coverage does not certify real inference.

The additional `Release readiness` job runs on PRs to `master`. It requires an
official `develop -> master` PR, checks the root package identity, SDK-only runtime
dependencies, minor/major release version (patch component zero) and changelog, consults
pub.dev, and performs
`dart pub publish --dry-run`. `CI result` requires it to pass for release PRs.
Other PRs cannot be used to bypass this branch requirement by naming a fork's
branch `develop`. PR evaluation has no publishing credentials or write access.

Every CI run checks that the root `pubspec.yaml` retains `name: jocaagura_ai`,
the official repository URL, a stable version, and no `publish_to` property.
This prevents publishing under a different package identity or regressing the
repository metadata check.

Require pull requests and the `CI result` check on `develop` and `master` in
GitHub branch rules. Require up-to-date checks, disallow direct/force pushes and
avoid bypass permissions on `master`. Restrict `v*` tag creation to release
maintainers and prohibit tag updates/deletion. These repository settings are
maintainer configuration; YAML cannot enforce branch protection by itself.
Do not use GitHub's CI-skip commit directives. CodeQL scans Actions workflows,
not Dart; retain the existing CodeQL configuration and checks.

### Local checks

Resolve dependencies in **both** tracked packages before analyzing the whole
repository. The server's mocked unit tests require no model; its existing native
build hook may prepare runtime libraries. It does not start the HTTP server.

```sh
dart pub get
(cd packages/jocaagura_ai_server && dart pub get)
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos --fatal-warnings .
dart test --coverage=coverage/raw
dart run coverage:format_coverage --lcov --in=coverage/raw --out=coverage/lcov.info --report-on=lib
(cd packages/jocaagura_ai_server && dart analyze --fatal-infos --fatal-warnings . && dart test --coverage=coverage/raw)
python -m pip install -r .github/scripts/requirements.txt
python -m unittest discover -s .github/scripts/tests -v
python .github/scripts/release_policy.py --metadata-only
dart pub publish --dry-run
```

Script tests use Bash (Git for Windows includes it). Use Dart 3.13.2 or a
compatible newer stable SDK. Update setup-dart steps if the minimum changes.

## Development patches and public promotions

Patches on `develop` record incremental progress and maintain their own dated
changelog entries. They are not automatic public releases. A public promotion
explicitly chooses **minor** or **major**; the patch component becomes zero.
For the current batch, **0.0.3 -> 0.1.0** is the chosen minor promotion. A major
promotion from 0.0.3 would instead produce **1.0.0**. The choice is deliberate;
CI does not infer compatibility from commit messages.

The API confirms that 0.0.3 already exists on pub.dev from the earlier manual
flow. Do not upload it again. The new automated publication policy rejects patch
versions, including already-published patches, and requires preparation of a
minor/major version before a PR can promote to `master`.

### Prepare the next promotion in GitHub Actions

1. Merge this implementation PR into `develop`; its workflow must exist on that
   default branch before GitHub allows dispatch.
2. Open **Prepare promotion**, select `develop`, enter `from_version: 0.0.3`,
   and choose `bump: minor`. CI calculates **0.1.0**. For later promotions,
   explicitly supply the development version and select minor or major.
3. The planner groups `Unreleased` and patch entries since the latest preceding
   `X.Y.0` promotion. It preserves Added/Changed/Fixed/etc. sections and labels
   each contribution with its original version. Here it collects **0.0.1,
   0.0.2 and 0.0.3**, plus pending release/Dartdoc changes. Previous promotion
   contents are not duplicated into later promotions; major promotions use the
   same boundary. Historical changelog blocks are never deleted or rewritten.
4. The workflow stores a reviewable notes/plan artifact, checks that its commit
   matches the dispatch commit, and calls the existing **Prepare version** flow.
   That flow runs full CI, checks the expected develop HEAD, prepares the version
   and dated consolidated changelog, clears `Unreleased`, and creates a
   GitHub-signed commit. The existing expected-HEAD API write also prevents
   overwriting concurrent work after validation.
5. If develop moved during planning/CI, dispatch again with the same source
   version after reviewing the change. Repeating the same dispatch inputs after
   preparation recognizes 0.1.0 and performs an idempotent no-op; it never bumps
   blindly to 0.2.0. New Unreleased contributions after preparation require review.
6. Open the release PR **develop -> master** only after version preparation.
   `Release readiness` rejects direct patch promotion and reports eligibility
   for the prepared minor/major version. It checks the version, changelog,
   repository identity and publication dry run alongside all existing CI gates.
7. CP-0 must pass before post-merge publication orchestration is implemented.
   Until then, merging a PR does not create a tag or publish. The documented
   human-tag fallback is available for a deliberately prepared release.

`Prepare version` remains the lower-level entry point for recording development
versions with an explicit version and canonical Base64 notes. Use **Prepare
promotion** for the public minor/major bump and automatic note consolidation.
If branch rules prevent the version commit, prepare the generated version/notes
through a normal PR into develop; do not weaken protections. The version commit
uses `GITHUB_TOKEN`, so its push does not start another CI run automatically;
the release PR and eventual human-pushed tag run CI again.

A local read-only preview of the exact promotion planner is:

```sh
python .github/scripts/prepare_promotion.py --from-version 0.0.3 --bump minor --output-dir .dart_tool/promotion-preview
```

The preview produces `plan.json` and `notes.md`, without changing package files,
creating a tag, committing, or uploading to pub.dev. The version bump occurs in
CI after this PR reaches develop; this PR therefore retains `version: 0.0.3`.

## CP-0 and publishing

[CP-0](CP0_AUTOMATED_PUBLISHING.md) is **pending**. Upstream code supports
`workflow_dispatch` on tags, but the live package configuration and OIDC
acceptance have not been verified. Automatic post-merge orchestration is not
implemented. No PAT, service account, external service or alternate credential
may be introduced to bypass the checkpoint.

The supported fallback is a human-pushed tag. Once the release PR has merged:

1. In pub.dev Admin, enable publishing from GitHub Actions for
   `grupo-jocaagura/jocaagura_ia`, pattern `v{{version}}`, with **push events**
   enabled. The present reusable publisher does not set an Environment. If the
   package requires one, configure that exact Environment in GitHub and pass it
   to the publisher before use; do not remove an existing protection to make a
   release work. Complete the CP-0 verification separately before enabling any
   post-merge dispatch path.
2. Fetch `master` and tags. Locate the exact `merge_commit_sha` of the merged
   official release PR, and check out that commit in a clean worktree.
3. Run release validation/CI and the publication dry run. Review the archive
   list: it must contain `lib/jocaagura_ai.dart`, the root example, README,
   changelog and license; it must exclude `packages/`, models, native runtimes,
   private config, and build/test reports.
4. For a genuinely unpublished, deliberately prepared version, create its
   `vX.Y.0` tag on that exact commit and push the tag explicitly as a human
   maintainer. Version 0.0.3 already exists: do not create or repoint its tag to
   imply that new unshipped changes belong to its published archive.
   If the tag exists, verify its peeled commit; never overwrite or re-create it
   to recover a failed release. No automation creates release tags in this stage.
5. `Publish package` verifies the human push event, tag/version/changelog, exact
   merged PR provenance and membership in `master` history. It checks pub.dev,
   performs a dry run and full CI, then uses the official Dart OIDC workflow.
   GitHub Release creation follows successful publication, or skips the upload
   if that version is already present. Uploads are serialized across versions.

A 404 for the entire package yields `manual_first_publication`; a tag run then
stops. Authentication errors, network errors, malformed responses and server
failures block publishing. Existing minor/major versions skip upload; a candidate older
than another published stable version is rejected, even if previously published.
Only an exact merged official `develop -> master` commit may be released;
an arbitrary ancestor of `master` is insufficient.

### Recovery and already-published versions

- `0.0.2` and `0.0.3` are already published. Do not publish them again, fabricate
  merge provenance, or repoint a historical tag. Review the original
  validated commit separately if historical release metadata is needed.
- If publication fails ambiguously, rerun the **entire workflow** so eligibility
  queries pub.dev again before uploading. A full rerun of a successfully
  published version skips the upload.
- If only GitHub Release creation fails after publication, rerun that failed job;
  it creates or updates release notes without uploading the package again.
- A conflicting tag, invalid source PR, failed CI, or API error requires fixing
  the underlying cause. Never move a release tag or bypass CP-0 as recovery.

## pub.dev diagnostics and package identity

The canonical published package is **jocaagura_ai**, first published manually as
**0.0.2**. Its [score API](https://pub.dev/api/packages/jocaagura_ai/score) reports
**160/160** points, verified on 2026-09-12. Its repository URL correctly points to
`grupo-jocaagura/jocaagura_ia`, whose default branch is `develop`; the repository
name and Dart package name do not need to be identical.

The 150/160 repository-mismatch report belongs to the different published
`jocaagura_ia` package. Do not rename the canonical package to address that old
report. Keep `name: jocaagura_ai`, its public entrypoint and imports unchanged.

The analysis log inspected during initial discovery reported an unresolved
Dartdoc reference for `[0, 1]`. This PR escapes that interval as code. Regenerating
Dartdoc must report zero warnings and errors. Published archives cannot be edited;
the correction remains under `Unreleased` and will reach pub.dev in a future
unpublished version selected by the maintainer. Do not claim to have increased points that
were already at their maximum.

References: [Dart publishing](https://dart.dev/tools/pub/automated-publishing),
[GitHub token event rules](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow),
[published analysis log](https://pub.dev/packages/jocaagura_ai/score/log.txt).
