# jocaagura_ia CI/CD

The root package is the SDK-only `jocaagura_ia` domain. Its first manual pub.dev
release is **0.0.1**; **0.1.0** is the next candidate. The integration consumer
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
dependencies, stable version and changelog, consults pub.dev, and performs
`dart pub publish --dry-run`. `CI result` requires it to pass for release PRs.
Other PRs cannot be used to bypass this branch requirement by naming a fork's
branch `develop`. PR evaluation has no publishing credentials or write access.

Every CI run checks that the root `pubspec.yaml` retains `name: jocaagura_ia`,
the official repository URL, a stable version, and no `publish_to` property.
This prevents the package/repository mismatch that lost 10 pub points.

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
python .github/scripts/release_policy.py
dart pub publish --dry-run
```

Script tests use Bash (Git for Windows includes it). Use Dart 3.13.2 or a
compatible newer stable SDK. Update setup-dart steps if the minimum changes.

## Version preparation

The 0.1.0 candidate is prepared in this change. For later releases:

1. Integrate contributions through PRs into `develop`, with notes under
   `## Unreleased` in `CHANGELOG.md`.
2. Run `Prepare version` on `develop` with a higher stable `X.Y.Z` and canonical
   UTF-8 Markdown release notes encoded as Base64. Notes must contain `###`
   sections without `##` headings. `0.0.0`, prereleases and build suffixes are
   not accepted for releases.
3. The workflow runs CI, prepares the version and dated changelog, and creates
   a GitHub-signed commit on `develop` using an expected-HEAD check. Identical
   repeated input is a no-op; conflicting notes or concurrent HEAD changes fail.
   If branch rules prevent that commit, prepare the files via a normal PR into
   `develop`; do not disable branch protections.
4. Open a `develop -> master` PR. The release check reports
   `ready_for_human_tag`, `already_published`, or `manual_first_publication`, or
   fails with a reason. Merging without a version bump is allowed if the version
   is already published, but does not create a release.
5. Merge only after all required checks pass. No tag or publication is created
   by opening, updating or merging this PR while CP-0 is pending.

The preparation commit uses `GITHUB_TOKEN`; its push does not automatically
start another CI run. The integration PR and the human-pushed tag run CI again.

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
   list: it must contain `lib/jocaagura_ia.dart`, the root example, README,
   changelog and license; it must exclude `packages/`, models, native runtimes,
   private config, and build/test reports.
4. Create `v0.1.0` on that exact commit and push that tag explicitly as a human
   maintainer. Substitute the deliberately prepared version for future releases.
   If the tag exists, verify its peeled commit; never overwrite or re-create it
   to recover a failed release. No automation creates release tags in this stage.
5. `Publish package` verifies the human push event, tag/version/changelog, exact
   merged PR provenance and membership in `master` history. It checks pub.dev,
   performs a dry run and full CI, then uses the official Dart OIDC workflow.
   GitHub Release creation follows successful publication, or skips the upload
   if that version is already present. Uploads are serialized across versions.

A 404 for the entire package yields `manual_first_publication`; a tag run then
stops. Authentication errors, network errors, malformed responses and server
failures block publishing. Existing versions skip upload; a candidate older
than another published stable version is rejected, even if previously published.
Only an exact merged official `develop -> master` commit may be released;
an arbitrary ancestor of `master` is insufficient.

### Recovery and the already-published first version

- `0.0.1` has already been published manually. Do not publish it again, fabricate
  a merge provenance for it, or repoint a historical tag. Review the original
  validated commit separately if historical release metadata is needed.
- If publication fails ambiguously, rerun the **entire workflow** so eligibility
  queries pub.dev again before uploading. A full rerun of a successfully
  published version skips the upload.
- If only GitHub Release creation fails after publication, rerun that failed job;
  it creates or updates release notes without uploading the package again.
- A conflicting tag, invalid source PR, failed CI, or API error requires fixing
  the underlying cause. Never move a release tag or bypass CP-0 as recovery.

## Resolving the pub.dev repository warning

The published 0.0.1 metadata points to the official repository. Pana's analysis
log shows it fetched the default branch, **develop**, whose pubspec had been
renamed to `jocaagura_ai`. That no longer matched `name: jocaagura_ia` in the
published archive, producing the 150/160 score.

This change restores the published identity and imports, keeps the repository
URL, and corrects the Dartdoc interval reference. Merge the correction into
`develop` through its PR so pub.dev can inspect the matching manifest on its
actual default branch. The existing published version cannot be edited, and
this metadata correction does not require republishing 0.0.1. After pub.dev
reanalyzes the package, inspect its score/log to confirm the warning is gone;
a passing local check does not guarantee the displayed score has refreshed.

References: [Dart publishing](https://dart.dev/tools/pub/automated-publishing),
[GitHub token event rules](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow),
[published analysis log](https://pub.dev/packages/jocaagura_ia/score/log.txt).