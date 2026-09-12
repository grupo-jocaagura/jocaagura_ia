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
