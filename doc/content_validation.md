# Content domain validation — issue #7

The external review accepted the domain/serialization/assessor design and requested
explicit scope traceability. The consumer migration is now tracked separately in
[issue #10](https://github.com/grupo-jocaagura/jocaagura_ia/issues/10), with its own
commit and consumer validation in the server README. Both commits must be
integrated together; the intermediate core API change requires consumer migration.

The adopted maximum semantics are recorded in #7 and [content.md](content.md):
null means no maximum declared by that profile, not unlimited runtime resources,
and does not alone cause undetermined. Null support allowlists remain unknown.

Two optional review improvements are included: shared test helpers live in
`test/fixtures/` instead of importing another test entrypoint, and the deliberate
one-to-one part-variant/input-modality mapping is documented without another enum.

## Local evidence after external review

Baseline: `e2d205fb5646e102ed9117c513be9c52184136b9` (`develop`, package 0.0.2).
Validation toolchain: Dart SDK 3.13.2 on Windows. No version bump or release.

| Check | Result |
| --- | --- |
| Core tests | 206 passed, no failures or skipped tests |
| Core executable lib line coverage | 812/812 (100%); every new executable library file included |
| Strict analysis | No issues across core and consumer |
| Formatting | Clean |
| Documented JSON | Seven examples decode/encode using the actual factories |
| Domain example | Emits canonical mixed JSON and a declared incompatibility without inference |
| Production core imports | SDK-only; no IO, Flutter, FFI, provider or runtime package |
| Existing CI/release-script tests | 18 passed; workflows/scripts unchanged |

These are local checks, not a claim that hosted PR checks already ran. The PR
reports GitHub CI independently. The package dry-run before commit validated the
archive, with only the expected warning for uncommitted files. Publication itself
is excluded; the breaking API/writer migration needs a separate release decision.

## Reproduction

From the root, after dependency resolution:

```sh
dart format --output=none --set-exit-if-changed .
dart analyze --fatal-infos --fatal-warnings .
dart test --coverage=coverage/review-raw --reporter=json
dart run coverage:format_coverage --lcov --in=coverage/review-raw --out=coverage/lcov-review.info --report-on=lib
dart run example/jocaagura_ai_example.dart
python -m unittest discover -s .github/scripts/tests -v
```

Tests cover structural validation, legacy/canonical JSON, immutable value
semantics, source/MIME/Base64 rules, restrictive model/backend declarations,
null-maxima semantics, unknown bounded file sizes, and failure-before-execution.
Mock runtime rejection after matching declarations is covered separately.

The core suite requires no files, model weights, image codecs or native inference.
This certifies the pure domain contract, not real image inference, Gemma/llamadart
image support, devices, or offline multimodal execution. The prior committed
text-only POC evidence is historical and has not been altered or re-certified.
