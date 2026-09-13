# jocaagura_ai CI/CD

The root package is the SDK-only `jocaagura_ai` domain. Its first manual pub.dev
release was **0.0.2**. The first CI minor promotion **0.0.3 -> 0.1.0**
was published successfully through GitHub OIDC and scored **160/160**. The integration consumer
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

Patches on `develop` record incremental progress with their own dated changelog
entries. Public promotions explicitly select **minor** or **major**, resetting
the patch component to zero. CI does not infer compatibility from commit messages.
The completed first promotion consolidated 0.0.1, 0.0.2, 0.0.3 and Unreleased into
0.1.0 while preserving historical entries. Never upload those versions again.

### Prepare the next promotion

1. Record development patch versions using **Prepare version** on `develop`.
   For example, a future 0.1.1 or 0.1.2 records progress toward the next promotion.
2. Run **Prepare promotion** on `develop` with the exact current `from_version`
   and choose `bump: minor` or `major`. For example, **0.1.2 -> 0.2.0** is a minor
   bump and **0.1.2 -> 1.0.0** is a major bump; these are examples, not existing releases.
3. The planner consolidates Unreleased plus patches after the latest preceding
   X.Y.0 promotion. It retains section names and source-version labels, preserves
   historical changelog blocks, and stores a reviewable notes/plan artifact.
4. Full CI and expected-HEAD checks precede the GitHub-signed version/changelog
   commit. Concurrent changes fail closed. A retry with the same source/bump
   recognizes an already-prepared target instead of bumping it again. New
   Unreleased contributions after preparation require review.
5. Open the official **develop -> master** PR. Release readiness checks the
   minor/major version, provenance, metadata, changelog, pub.dev and dry run.
6. Merge after required checks pass. **Release after master merge** then handles
   tag creation and publication dispatch as described below.

`Prepare version` remains the lower-level entry point for recording explicit
patch versions and Base64 notes. Use **Prepare promotion** for public minor/major
bumps and consolidation. If branch rules block version commits, use a normal PR;
do not weaken protections. A GITHUB_TOKEN version push does not trigger branch
CI, but the release PR and publishing pipeline run CI again.

A local read-only preview (substitute the actual current development version):

```sh
python .github/scripts/prepare_promotion.py --from-version 0.1.2 --bump minor --output-dir .dart_tool/promotion-preview
```

The preview writes plan.json and notes.md only. The actual bump occurs in CI
before the release PR, not after its merge. This implementation retains the
already-published version 0.1.0; its automation changes remain under Unreleased.

## Automated publication after merge

[CP-0 passed](CP0_AUTOMATED_PUBLISHING.md#cp-0-completion): live pub.dev accepted
workflow_dispatch on a GITHUB_TOKEN-created tag, and the maintainer confirmed
matching audit attribution. Exact claims, configuration and archive evidence are
in [evidence/cp0-0.1.0.json](evidence/cp0-0.1.0.json).

1. A push to `master` starts **Release after master merge**. The trusted master
   checkout must equal the event SHA. The exact commit must be the merge result
   of an official develop -> master PR; direct commits and unrelated/fork PRs fail.
2. The read-only plan requires completed CP-0 evidence, a valid minor/major
   version and changelog, and the live pub.dev version state. Existing versions
   finish as `already_published` before tag inspection or mutation. An absent
   package, patch version, regression or service error blocks the release.
3. An unpublished candidate must pass the dry run and full CI. Only the final
   dispatch job receives contents:write and actions:write. It repeats provenance,
   current-master and public-version checks immediately before writing.
4. GITHUB_TOKEN creates `vX.Y.0` at the validated merge SHA. An existing tag must
   resolve to that exact commit, including annotated tags; conflicts fail without
   replacement. The workflow then dispatches **Publish package** with that tag
   as the ref. No PAT, service account or additional service is used.
5. **Publish package** accepts tag-ref workflow_dispatch or a human tag push.
   It validates provenance/version again, runs full CI and dry run, and uses the
   official Dart reusable OIDC publisher. GitHub Release creation follows upload
   success, or updates release notes when the same tagged version already exists.

The GITHUB_TOKEN-created tag push does not itself run another push workflow.
The explicit dispatch is necessary. Publisher runs share the global
`pub-dev-release` concurrency group; the orchestrator uses a different group so
waiting publishers cannot deadlock their dispatcher. Duplicate orchestration runs
of the same commit serialize. Public version checks reject regressions even if
multiple releases are prepared close together. Never bypass a failed or stale run.

The dispatch workflow must exist on the default branch (`develop`) and target
tag. Keep pub.dev configured for repository `grupo-jocaagura/jocaagura_ia`, pattern
`v{{version}}`, workflow_dispatch and push enabled, with no required Environment.
If an Environment becomes required, configure the same value in the publisher;
do not remove an existing protection. The verified OIDC subject includes immutable
repository and owner IDs; the official publisher handles token acquisition.

### Recovery

- If master changes before planning or dispatch, the run fails before a new tag
  is created. Evaluate the current master candidate; do not override the SHA check.
- If dispatch fails after tag creation, rerun **Release after master merge** on
  `master` while it still points to that candidate. The existing matching tag is
  preserved and dispatch is retried. A successful API dispatch only means queued;
  inspect **Publish package** for the actual publication result.
- If publication fails, rerun the **entire Publish package workflow**, so it checks
  pub.dev again. Do not rerun only the upload job after an ambiguous result.
  If upload succeeded but GitHub Release creation failed, rerun only that final job.
- Existing published versions skip uploads. The initial 0.1.0 activation merge
  therefore leaves its published tag and archive untouched even though master has
  advanced. Its immutable tag remains at d60302c7ad0f65b25356fb02516fb899597e42aa.
- For an existing older candidate after master advanced, a maintainer can dispatch
  **Publish package** directly on its immutable tag; all provenance/version/CI
  gates still apply. The workflow must be present at that tag. Old pre-dispatch
  tags do not retroactively receive new workflow definitions.
- An explicitly human-pushed tag remains the fallback for an unpublished prepared
  release at the exact official merge commit. Never move/delete a release tag.
  The recorded one-time pre-publication recovery of 0.1.0 is not a standing exception.
- Merge release PRs as a maintainer. GitHub does not generate push/closed-PR runs
  for merges made with GITHUB_TOKEN. If such a merge occurs, explicitly dispatch
  **Release after master merge** on master rather than introducing other credentials.

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
the correction is present in the published 0.1.0 archive, whose analysis
reports zero Dartdoc warnings/errors and 160/160 points. Do not claim to have increased points that
were already at their maximum.

References: [Dart publishing](https://dart.dev/tools/pub/automated-publishing),
[GitHub token event rules](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow),
[published analysis log](https://pub.dev/packages/jocaagura_ai/score/log.txt).
