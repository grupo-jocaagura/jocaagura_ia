# jocaagura_ia CI/CD

This project is a Dart package. `0.0.0` identifies the local bootstrap and
cannot be published through the workflow. The minimum Dart version is 3.13.2.

## Continuous integration

`Dart CI` runs on pushes to any branch, pull requests targeting `develop` or
`master`, manual runs, and calls from version preparation or publishing workflows.
Jobs do not skip bot actors or pull requests with `[skip ci]` in their titles.
GitHub still recognizes its own skip instructions in commit messages: configure
`CI result` as a required check to prevent merging changes without validation.
Do not use CI skip instructions.

Checks include GitHub-verified commit signatures, the absence of tracked dependency
overrides, formatting, strict analysis, release script tests, workflow validation
with actionlint, Dart tests, and LCOV coverage. Commit queries use pagination;
the first push validates the entire history. Manual runs verify the signature
of the selected commit.

The minimum coverage is **95%**, with a target of **100%**. The optional Actions
variable `COVERAGE_MIN` can only raise the threshold, up to 100. The actual ratio
is compared without rounding. Missing tests or executable lines cause CI to fail.
Reports are retained for 14 days. Coverage measures the lines in `lib` reported
by the VM during tests; it does not guarantee that files never loaded are included.
The initial domain suite exercises the public models and result/lifecycle
contracts. Its coverage does not certify runtime integration or real inference.

CodeQL analyzes the `actions` language: the workflows themselves. It does not
analyze Dart. It runs on pull requests and pushes to the main branches, and weekly.

### Local checks

```sh
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos --fatal-warnings .
dart test --coverage=coverage/raw
dart run coverage:format_coverage --lcov --in=coverage/raw --out=coverage/lcov.info --report-on=lib
python -m pip install -r .github/scripts/requirements.txt
python -m unittest discover -s .github/scripts/tests -v
```

Script tests require Bash, which is included in Git for Windows. If the minimum
SDK version changes, update the `setup-dart` steps in CI and publishing workflows.
Nested packages with tests must also declare `coverage` as a development dependency.

## Version preparation

1. Add contributions under `## Unreleased` in `CHANGELOG.md`.
2. Run `Prepare version` with the `develop` branch selected.
3. Provide a stable `X.Y.Z` version higher than the current one, such as `0.0.1`,
   and Base64-encoded UTF-8 Markdown notes. The notes must contain `###` sections,
   such as `### Added` or `### Fixed`, without `##` headings.
4. The workflow runs CI, moves the notes to `## [X.Y.Z] - YYYY-MM-DD`, keeps an
   empty `Unreleased` section, and creates a GitHub-signed commit on `develop`.
5. Merge `develop` into `master` through a pull request with passing CI.

This flow only supports stable releases; `+build` suffixes and prereleases are
not accepted. Repeating the same version with the same notes does not create
another commit; changing the notes of a prepared version produces an error.
The update checks the expected HEAD to avoid overwriting concurrent changes.
If HEAD changes, run the workflow again.

The preparation commit uses `GITHUB_TOKEN`, whose push does not trigger another
CI run. CI therefore runs before the two version files are modified, and runs
again for the integration pull request and the publishing tag. If branch rules
prevent the workflow from committing directly to `develop`, the operation fails.
In that case, prepare those two files through a regular pull request without
disabling branch protections.

## Publishing

The `Publish package` workflow is triggered by a `vX.Y.Z` tag. It checks that the
commit belongs to the history of `master`, the tag matches `pubspec.yaml`, and
the version differs from `0.0.0` and has exactly one dated changelog entry with
content. It runs `dart pub publish --dry-run`, the full CI pipeline, and the
official Dart publishing workflow using OIDC without long-lived tokens.
It then creates a GitHub Release with that version's notes. If only GitHub
Release creation fails, rerun the failed jobs to avoid repeating a publication
that already succeeded.

## Official repository setup

- Create an empty repository and connect its URL as `origin`; push `master`
  and `develop`. Add that URL to the `repository` field in `pubspec.yaml`.
- Register the public key used to sign local commits on GitHub so they appear
  as `Verified`. CI requires this verification from the first push.
- Configure `CI result` as a required check and require pull requests for
  integration into `master`. Configure CodeQL according to the repository's
  code scanning availability.
- Omit `COVERAGE_MIN` to use 95%, or set it to a value between 95 and 100.
- Complete the package description, README, and functionality before the first
  publication. Keep accurate notes for the version being published.
- A maintainer must publish a new package for the first time. Then enable
  Automated publishing on pub.dev for the official repository and the
  `v{{version}}` pattern. For that first version, publish manually from the
  validated commit and then create its tag/release; the OIDC job cannot publish
  the same version again. Subsequent tags use the complete workflow.
- Restrict creation and modification of `v*` tags to release maintainers.

The bootstrap dry run will still warn that `0.0.0` has no release entry.
This is intentional at this initial stage; the workflow blocks its publication.
The official URL is already declared in `pubspec.yaml`.

References: [Dart automated publishing](https://dart.dev/tools/pub/automated-publishing),
[events and GITHUB_TOKEN](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow),
[CodeQL languages](https://codeql.github.com/docs/codeql-overview/supported-languages-and-frameworks/).
