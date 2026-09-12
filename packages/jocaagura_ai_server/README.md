# Jocaagura AI server POC

A nonpublishable, pure Dart integration consumer of `jocaagura_ai`. The server
owns HTTP, composition and the concrete `LocalAiGateway`. The core package has
no dependency on this server, Flutter, llamadart or HTTP.

```text
HTTP controller -> ModelAiRequest -> AiGateway -> LocalAiGateway -> LiteRT-LM CPU
direct smoke --------------------------^                          -> local Gemma
```

This POC is intentionally limited to `gemma-4-e2b-poc`: one user text message
(up to 4096 characters), `maxOutputTokens` 1..128 (null defaults to 32),
`temperature` 0 (null defaults to 0), and empty `stopSequences`. Other IDs return
`modelUnavailable`; unsupported request shapes/options return `invalidRequest`.
The native sampler uses top-k 1, top-p 1 and seed 42 with thinking disabled.
The local model bundle's chat template is used; no prompt/output rewrite forces
the expected `OK` answer. Multimodal payloads, tools and cloud fallback are absent.

## Prepare the environment

Use Dart 3.13.2. From this directory:

```sh
dart pub get
dart analyze --fatal-infos --fatal-warnings .
dart test --coverage=coverage/raw
dart run coverage:format_coverage --lcov --in=coverage/raw --out=coverage/lcov.info --report-on=lib
```

`llamadart` is pinned to 0.8.23; the server lockfile pins transitive dependencies.
The hook selects only LiteRT-LM and prepares its native assets on build/run.
Tests use a mocked engine and need no weights; hooks may download native assets
before tests. Run preparation while networking is available. The core's separate
tests do not require a runtime.

For the selected Windows x64 CPU POC, download this exact artifact manually:

- Repository: [litert-community/gemma-4-E2B-it-litert-lm](https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm).
- Revision: `b3ca0d2f076785a8f4b2219ddbd2bdb99954eae1`.
- File: `gemma-4-E2B-it.litertlm`, 2,588,147,712 bytes.
- SHA-256: `181938105e0eefd105961417e8da75903eacda102c4fce9ce90f50b97139a63c`.
- License: Apache 2.0 according to the artifact card and official Gemma 4 card.
- Quantization: upstream mobile mixed 2/4/8-bit weights; not a GGUF quantization.
- Runtime: `leehack/litert-lm-native@v0.16.0-native.2`, CPU, four threads,
  context budget 2048. Other artifact/backend/platform combinations are untested.

From the repository root, PowerShell preparation is:

```powershell
New-Item -ItemType Directory -Force .local | Out-Null
curl.exe --fail --location --output .local/gemma-4-E2B-it.litertlm 'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/b3ca0d2f076785a8f4b2219ddbd2bdb99954eae1/gemma-4-E2B-it.litertlm'
Get-FileHash -Algorithm SHA256 .local/gemma-4-E2B-it.litertlm
```

Compare the hash and byte size with the values above before using the file.
The source/revision identifies the test input; a locally computed hash alone is
not a trust guarantee. This manual preparation is not a model downloader or an
`AiModelManager` implementation. Weights and private evidence stay in ignored
`.local/` and are never part of the source/package archive.

## Run directly or through HTTP

From this directory, set an absolute local model path:

```powershell
$env:JOCAAGURA_MODEL_PATH = (Resolve-Path '../../.local/gemma-4-E2B-it.litertlm').Path
dart run bin/jocaagura_ai_server.dart smoke
dart run bin/jocaagura_ai_server.dart serve
```

`smoke` invokes `AiGateway` directly with `Respond only with OK`, outputs the
unaltered response in a diagnostic report, closes resources and exits. Exit 0
requires matching IDs, `completed` and `text.trim() == 'OK'`; a truncated result
fails the smoke check even when its text happens to be `OK`. This diagnostic
report wraps the payload for the command; `AiResult` has no serialization API.

`serve` listens only on `127.0.0.1:8080`. Call it from another terminal:

```powershell
$body = '{"requestId":"http-poc-1","modelId":"gemma-4-e2b-poc","messages":[{"role":"user","content":"Respond only with OK"}],"options":{"maxOutputTokens":32,"temperature":0,"stopSequences":[]}}'
Invoke-RestMethod -Uri http://127.0.0.1:8080/v1/inference -Method Post -ContentType application/json -Body $body
```

The controller decodes `ModelAiRequest.fromJson`, calls the injected gateway,
and returns `ModelAiResponse.toJson()` (200) or `ModelAiFailure.toJson()`:

| Failure | HTTP |
| --- | --- |
| Malformed JSON/domain payload, invalidRequest | 400 |
| Body larger than 32768 bytes | 413 |
| unsupportedCapability | 422 |
| modelUnavailable, insufficientResources | 503 |
| integrityFailure, modelLoadFailure, inferenceFailure | 500 |

The HTTP mapping covers the whole existing failure enum; it does not mean this
POC detects every resource/integrity failure. Local file read failures map to
`modelUnavailable`; typed engine load/inference/unsupported exceptions are mapped
by phase. There is no checksum verification on every request, no heuristic
out-of-memory detection, and no automatic retry. The caller can correct a missing
file/configuration before making another request. HTTP hides unexpected errors;
the adapter propagates programming errors after attempting cleanup.

## Session ownership and finish reasons

Each accepted request opens a new engine session, loads the local artifact,
generates and disposes before returning. Requests never share chat history.
Concurrent requests on one gateway are rejected as busy (`invalidRequest`).
Closing rejects new work and waits for active work/cleanup; it does not cancel it.
Ctrl+C closes the listener and drains accepted work. Disconnecting an HTTP client
does not cancel inference. There is no partial manager implementation or new
domain lifecycle state.

The pinned chat parser emits `stop` even at the output budget. The adapter uses
native per-session decode counts to report `outputLimit` when the budget was
reached, otherwise `completed`. At the exact boundary it conservatively reports
`outputLimit` rather than claiming a natural stop. Missing/invalid terminal
diagnostics fail closed. Native counts include runtime termination processing;
they are not counts of words or visible strings. Total token usage remains null
because the runtime does not report that separate measurement through this path.

## Bundle and offline certification

Build while online, from this package directory:

```powershell
dart build cli --target=bin/jocaagura_ai_server.dart --output=../../.local/server-build
$env:LLAMADART_LITERT_LM_LIB_DIR = (Resolve-Path '../../.local/server-build/bundle/lib').Path
& '../../.local/server-build/bundle/bin/jocaagura_ai_server.exe' smoke
```

Use `dart build cli`, since this dependency has native build hooks. Keep the
whole `bundle` together and set `LLAMADART_LITERT_LM_LIB_DIR` to its absolute
`lib` directory. The pinned runtime's Windows library lookup otherwise depends
on the working directory/cache; an executable-only copy is insufficient. The
bundle carries six upstream DLLs, including companion libraries; CPU is selected
explicitly even when GPU-related companion files are present.

After the HTTP test and build, run the following from an **administrator
PowerShell**. It temporarily disables connected physical network adapters,
executes two fresh direct-mode processes, then restores the adapters in a
`finally` block. Each process has a two-minute external test timeout; that timeout
does not implement active cancellation. The report and raw logs stay in `.local`.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File './tool/certify_offline.ps1'
```

The execution-policy override applies only to this process; it does not change
the machine's saved policy. Run from this package directory with the network
connected so the script can restore the adapters it disables.

This checks the physical network-disconnection scenario and direct execution;
it is not a packet-capture audit. Keep raw device inventory private and review
the report before sharing it. A skipped/failed offline run remains pending even
if unit tests and the online HTTP test pass. See [recorded evidence](../../doc/local_inference_poc.md).

Production HTTP deployment, authentication, acquisition/installation, public
streaming, active cancellation, multimodal requests and other providers are
separate work.
