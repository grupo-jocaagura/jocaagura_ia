# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

- [Added] for new features.
- [Changed] for changes in existing functionality.
- [Deprecated] for soon-to-be removed features.
- [Removed] for now removed features.
- [Fixed] for any bug fixes.
- [Security] in case of vulnerabilities.

## Unreleased

### Fixed

- Escape the progress interval in Dartdoc so it is not treated as a link
  (issue #8).

### Added

- Prepare explicit minor/major promotions in CI, consolidating Unreleased notes
  and development patches since the previous promotion without deleting history.
- Require public release versions to end in `.0`; development patches cannot
  be published through the automated release route.

- Validate release PR provenance, package identity, changelog and pub.dev version
  eligibility before integration into `master`.
- Make human-tag publication retries skip versions already published, while
  rejecting regressions, inconsistent metadata and invalid release provenance.
- Record CP-0 evidence and keep automatic post-merge orchestration unimplemented
  until tag-ref workflow dispatch is verified against the live pub.dev settings.

## [0.0.3] - 2026-09-13

### Added

- Add immutable ordered text/image input parts, inline-byte and lexical local-file
  content sources, canonical JSON, descriptive string metadata and pure validation.
- Add directional model/backend content declarations and a pure compatibility
  assessment distinguishing unsupported, undetermined and meeting declarations.
  Null allowlists mean unknown; null maxima impose no declared bound.

### Changed

- Migrate `ModelAiMessage` from `content` to `parts` (breaking Dart API and JSON
  writer change). Read legacy textual JSON; write only parts; reject both keys.
  Provide explicit single-text construction without lossy mixed-content getters.
- Add optional descriptor content capabilities without inferring runtime support.
- Companion consumer migration: retain the server's textual behavior and reject
  images/multipart input before resource access. No image inference is implemented.

## [0.0.2] - 2026-09-12

### Changed

- Rename the Dart package and public library to `jocaagura_ai`, including imports,
  examples and documentation. The GitHub repository remains `jocaagura_ia`.
  Consumers must migrate their dependency/import names; domain JSON is unchanged.
- Enforce the coverage minimum for each package as well as the combined report.

### Added

- Add the nonpublishable pure Dart `jocaagura_ai_server` integration consumer,
  implementing `AiGateway` with embedded Gemma 4 E2B via llamadart/LiteRT-LM CPU.
- Add `POST /v1/inference` and a socket-free smoke mode sharing one composition
  root, with local resource ownership, bounded requests and domain error mapping.
- Add adapter/HTTP tests and reproducible local POC preparation instructions.

## [0.0.1] - 2026-09-12

### Added

- Add ten immutable ModelAi values, six EnumAi enums, exhaustive AiResult variants,
  and pure Dart inference/model-management interfaces (issue #3).
- Require failed lifecycle recovery through verified resource states and defer
  active cancellation to a future execution/streaming contract.
- Define strict JSON decoding, deterministic round trips, nullable copy semantics,
  source integrity invariants, and explicit lifecycle transitions.
- Document the domain contract and provide a runtime-free executable example.

- Document the local AI discovery, proposed contracts, and initial offline POC.
- Validate tagged releases and publish to pub.dev through OIDC after CI passes.
- Document CI/CD setup and test version preparation and coverage gates.

### Changed

- Replace the Awesome scaffold with an SDK-only domain and comprehensive tests.

- Standardize CI/CD documentation, package metadata, and workflow comments in English.
- Set the official public repository URL and describe the local AI package scope.
- Adapt continuous integration to the Dart package, including strict analysis,
  tests, a minimum of 95% coverage, and commit signature verification.
- Prepare package versions using the X.Y.Z format and Keep a Changelog entries.

### Fixed

- Replace copied README badges with this package's bootstrap status and coverage requirement.
- Remove obsolete analyzer rules and unused package scaffold code.
- Correct CodeQL language selection and ensure CI runs on integrated changes.
