# Local inference POC evidence

Issue: [#5](https://github.com/grupo-jocaagura/jocaagura_ia/issues/5).
Implementation is based on `d45c8b79897e76776604ebbefd0575fc640d2185` (`develop`).
No release or additional bump is made.

## Selected tuple

One physical Windows x64 computer, CPU only. Detailed device inventory and raw
logs remain local for review. This does not certify other computers or backends.

- Dart 3.13.2; `llamadart` 0.8.23 with locked transitive dependencies.
- `leehack/litert-lm-native@v0.16.0-native.2`, Windows x64 runtime bundle.
  Local archive SHA-256:
  `d7e997b12f6c39e4bac0cb878d824e05f1b4bae21768a407b150c14cb998f13f`
  (28,734,437 bytes).
- `litert-community/gemma-4-E2B-it-litert-lm` revision
  `b3ca0d2f076785a8f4b2219ddbd2bdb99954eae1`.
- `gemma-4-E2B-it.litertlm`: 2,588,147,712 bytes; verified SHA-256
  `181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c`.
- Artifact card: Apache 2.0, upstream mobile mixed 2/4/8-bit quantization.
- Embedded chat template from the artifact/runtime, native chat message with
  `user` role, `enableThinking: false`; no custom template or prompt rewrite.
- CPU, four threads, context 2048; max output 32, temperature 0, top-k 1,
  top-p 1, seed 42, no speculative decoding and no custom stop sequences.

Preparation downloaded model/runtime while online. Inference loads the model
from its absolute local path; the bundle uses an explicit absolute DLL directory.
The model is excluded from Git and package publishing.

## Results observed during implementation

| Check | Evidence |
| --- | --- |
| First direct Dart inference | `OK`, completed, inputTokens 13, outputTokens 2, totalTokens null; 8001 ms including session setup/cleanup |
| Bundled direct inference | `OK`, completed; 2070 ms in a subsequent run; no performance guarantee |
| Actual HTTP endpoint | 200; requestId `http-poc-1`, modelId `gemma-4-e2b-poc`, text `OK`, completed, 13 input / 2 output tokens |
| Native one-token output budget over HTTP | 200; text `OK`, outputLimit, 13 input / 1 output token; intentionally fails the stricter smoke completion check |
| Invalid HTTP domain payload | 400; ModelAiFailure code invalidRequest; gateway not called |
| Two fresh processes with physical network disabled | Passed on 2026-09-12 at 22:28 UTC: both exit 0, text `OK`, completed, 13 input / 2 output tokens; 3261 ms and 1975 ms |

The administrator-run `tool/certify_offline.ps1` recorded two distinct process
IDs and no physical adapter with status `Up` before or after either inference.
The script restored the initially connected adapters and reported success.
Raw evidence remains in the ignored `.local/offline-evidence.json`; its model
hash matches the pinned artifact above. The executable hash was checked against
the current bundle:
`b0a6080c45e6c43d28092c535389ac55d26255ea0ed2d88a5e8c1f3fa05053e5`.
This certifies these two direct, socket-free runs on the selected computer.

The one-token run confirms why visible text alone cannot distinguish natural
completion from the output limit. Responses keep the runtime text unchanged.

An initial bundled run from a different working directory failed with missing
native-library lookup. Setting `LLAMADART_LITERT_LM_LIB_DIR` to the bundle's
absolute `lib` path resolved it; this is included in the reproducible commands.

## Validation and limits

- Domain: 133 tests pass after import migration; 413/413 executable lib lines
  covered (100%); public type/JSON contract unchanged.
- Server: 25 automated tests for mapping, input rejection, terminal diagnostics,
  ownership/cleanup, concurrency and HTTP composition. These use mocked engines;
  they do not prove real inference. All three server lib files are loaded.
- Server Dart line coverage: 129/130 (99.23%) in the initial suite; the uncovered
  engine-construction line is exercised by real runs outside unit coverage.
- CI/release script checks: 18 tests; actionlint passes. The coverage gate now
  enforces each package individually so the core cannot conceal missing tests
  in the server.
- Strict analysis, formatting and the renamed domain example pass. The pre-commit
  publication dry-run validates the approximately 30 KB core archive, excluding
  the server and weights. Exit 65 has only the expected uncommitted-files warning.
  Post-commit validation is recorded in the pull request. Nothing was published.

Full lifecycle management, integrity verification as a product capability,
multimodal use, Flutter, acceleration beyond CPU, cancellation and cloud inference
are not implemented. Root pubspec remains SDK-only. Exact source/commands and
offline procedure are in the [server README](https://github.com/grupo-jocaagura/jocaagura_ia/tree/develop/packages/jocaagura_ai_server).
