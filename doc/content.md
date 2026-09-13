# Ordered content and declared compatibility

Issue [#7](https://github.com/grupo-jocaagura/jocaagura_ia/issues/7) extends the
SDK-only core from the `develop` baseline `e2d205f` (package 0.0.2). This is an
Unreleased breaking message API/writer change. No release is performed here.

## Scope and migration

Inputs are text and images; generated output remains `ModelAiResponse.text`,
including valid empty output. Images exercise heterogeneous order, MIME and
resource ownership without requiring audio/video timing or codec contracts.
Representability never establishes Gemma/llamadart support. Real image execution,
streaming, cancellation, downloads and full model lifecycle are separate work.

`ModelAiMessage` owns a nonempty `List<ModelAiContentPart> parts` and the existing
role. `ModelAiTextPart` and `ModelAiImagePart` are final variants of a sealed
family, supporting exhaustive pattern matching. Roles remain system/user/assistant;
image-only messages are structurally valid for any role. Backend policies can
restrict roles and modalities independently of structural validity.

`EnumAiInputModality` deliberately also discriminates part variants: there is one
variant for text and one for image. If multiple variants of one modality are
needed later, reconsider that mapping then; no additional enum is needed here.

Replace `ModelAiMessage(role: role, content: text)` with
`ModelAiMessage.text(role: role, text: text)` for a single text part. Replace
`copyWith(content: ...)` with explicit replacement of `parts`. There is no
`content` getter or implicit flattening. Consumers inspect typed parts and reject
unsupported content before allocating resources. Two adjacent text parts remain
distinct from one concatenated part.

Readers accept **exactly one** message key, legacy `content` or canonical `parts`.
Key presence determines the branch: both keys are invalid even if one is null or
their apparent text agrees. Neither key, null, empty text or empty parts fail.
Legacy text becomes one part with empty metadata. Writers emit only `parts`.
Old readers need not accept new output; legacy input is normalized rather than
reproduced byte for byte. Release version selection remains a separate decision.

Legacy input:

```json
{"role":"user","content":"Describe the picture."}
```

Canonical equivalent:

```json
{"role":"user","parts":[{"type":"text","text":"Describe the picture.","metadata":{}}]}
```

Mixed request:

```json
{
  "requestId": "mixed-1",
  "modelId": "illustrative-model",
  "messages": [{
    "role": "user",
    "parts": [
      {"type":"text","text":"Describe:","metadata":{}},
      {"type":"image","mimeType":"image/png","source":{"type":"localFile","path":"fixtures/picture.png"},"metadata":{"label":"sample"}},
      {"type":"text","text":" Focus on the foreground.","metadata":{}}
    ]
  }],
  "options": {"maxOutputTokens":32,"temperature":0.0,"stopSequences":[]}
}
```

`options` remains required in request JSON, even though the Dart constructor
has a default. Responses, usage, finish reasons, request IDs and logical model
IDs retain their existing semantics; no requested-output selector is introduced.

## Parts and content sources

| Value | Required JSON keys | Optional/defaulted keys |
| --- | --- | --- |
| Message | role, parts (or legacy content) | None |
| ModelAiTextPart | type = text, text | metadata, defaults to {} |
| ModelAiImagePart | type = image, mimeType, source | metadata, defaults to {} |
| ModelAiInlineBytesSource | type = inlineBytes, bytesBase64 | None |
| ModelAiLocalFileSource | type = localFile, path | None |

Text must be nonempty, preserving whitespace and Unicode exactly; whitespace-only
text is valid. Images require exactly one source. `ModelAiContentSource` is a
separate sealed family from `ModelAiSource`, which still describes acquisition of
model weights and retains its existing SHA/download invariants.

Inline sources copy a nonempty `List<int>` whose elements are all in 0..255,
before any conversion could truncate out-of-range integers. The exposed list is
unmodifiable and does not expose a mutable typed-data buffer. JSON is standard
canonical padded Base64 as emitted by `base64Encode` (padding only when needed).
Decode and re-encode must reproduce the string exactly. Reject URL-safe alphabet
substitutions, whitespace, bad/noncanonical padding, data URI prefixes and empty
decoded payloads. Numeric byte arrays are not another wire representation.

```json
{"type":"image","mimeType":"image/png","source":{"type":"inlineBytes","bytesBase64":"AQID"},"metadata":{}}
```

`AQID` is [1, 2, 3], intentionally not a PNG. This is a valid structural fixture,
not an executable image or proof that its MIME matches the bytes. No codec runs.

File paths are nonblank, NUL-free strings preserved exactly. Relative/absolute
strings are representable; no normalization, expansion, current-directory lookup,
existence check or file opening takes place. Reject `://`, case-insensitive
`data:`/`file:` prefixes, and two leading slashes/backslashes (UNC/network-share
prefixes). Lexical validation cannot prove locality through symlinks or mounts.
Applications resolve access, enforce actual locality and apply their own policy.
References are not permission to read files, download data or perform inference.

MIME normalization lowercases ASCII only, then requires the complete string to
match `^image/[a-z0-9][a-z0-9!#$&^_.+-]*$`. Reject whitespace (including trailing
newlines), parameters, wildcards, non-image top-level types and empty subtypes.
No aliasing, registry lookup, extension inference or sniffing is performed:
`image/jpg` differs from `image/jpeg`. Syntactic MIME acceptance does not imply a
supported decoder or even a real registered image type.

Part metadata is a flat `Map<String,String>`. Nonblank keys and arbitrary string
values (including empty values) are preserved. Absence defaults to {}; explicit
null, non-string values, nested collections and null values fail. Metadata is
descriptive: it cannot provide MIME, sources, capability overrides or provider
parameters. The core never interprets vendor-prefixed keys as runtime controls.
No arbitrary object serialization, coercion, or automatic `toString` occurs.
Applications independently bound metadata/payload sizes; the domain imposes no
universal runtime memory budget.

URLs, data URIs, asset resolvers, provider file IDs, audio, video, generic
documents, tools and generated images have no placeholder variants here.

## Validation, serialization and immutable values

- Discriminators/enum values are exact case-sensitive strings, never ordinals.
  Missing/null/unknown values, primitive parts, null list elements and malformed
  nested objects fail closed. Unknown parts are never skipped or made into text.
- Required fields reject absence/null. Defaulted metadata rejects null. Nullable
  profile/allowlist/maximum fields accept absence/null and always serialize as
  explicit null. Required sets remain required even if empty sets are meaningful.
- Unknown object keys are ignored and not re-emitted for additive compatibility.
  Known incompatible fields are rejected even when null: text forbids
  mimeType/source, image forbids text, inlineBytes forbids path, localFile forbids
  bytesBase64. This is checked before ignoring truly unknown keys. Duplicate raw
  JSON object keys are a parser/transport concern; a Map reader cannot recover
  duplicates already discarded by `jsonDecode`.
- Constructors/copies throw `ArgumentError` without relying on assertions;
  JSON factories throw `FormatException`, with nested field/index context.
  Diagnostics do not expose raw Base64 bytes or full file paths. Runtime
  incompatibility is not a structural constructor error.
- All concrete content values have `fromJson`, `toJson`, `copyWith`, equality
  and hashing. Copy omission preserves values. Explicit null clears nullable
  fields only and is rejected for required/defaulted fields. New copy parameters
  use the existing sentinel pattern with runtime type validation. Construct
  another variant to change a discriminator. Existing unrelated copy APIs retain
  their documented behavior.
- Input collections are defensively copied/frozen. Exported JSON is independent.
  Parts, messages, byte sequences and reasons have ordered equality/hashing;
  capability sets and metadata maps ignore insertion order. Equality includes
  variant, exact text/path/bytes, normalized MIME and metadata. Paths compare by
  string, never filesystem identity. Hashes are not promised stable across SDKs
  or processes.
- Writers emit fields in the schema/table order: message role/parts; part
  type/text-or-mimeType/source/metadata; source type/payload; profile fields in
  the following table order; report status/reasons. Metadata keys and sets sort
  lexically; sequence order is untouched. Descriptor contentCapabilities follows
  source. No sorting, coalescing or deduplication of input parts occurs.
- Actual model -> JSON map -> jsonEncode -> jsonDecode -> model round trips
  preserve equality/hash and stable canonical re-encoding. Ignored unknown keys
  and legacy writer layout are intentionally outside that guarantee.

## Directional declarations

`ModelAiContentCapabilities` may be attached to
`ModelAiDescriptor.contentCapabilities` or supplied separately as a backend
declaration by composition code. Legacy descriptors decode to a null profile,
and writers include `contentCapabilities: null`. No profile is inferred from a
model brand or from `EnumAiCapability.textGeneration`. That existing coarse task
capability is retained; when a descriptor supplies a content profile, its outputs
must include text. A standalone backend profile may explicitly declare no output.
No backend identifier, provider DTO, runtime version or new discovery method is
added to the core, and requests still contain only logical model IDs.

| Field | Semantics |
| --- | --- |
| inputModalities | Required set: text and/or image; [] accepts no input |
| outputModalities | Required set: text only; [] produces no output |
| inputRoles | Nullable set of existing roles; null unknown, [] accepts none |
| imageSourceTypes | Nullable inlineBytes/localFile set; null unknown, [] none |
| imageMimeTypes | Nullable normalized MIME set; null unknown, [] none |
| maxMessagesPerRequest | Nullable positive integer, messages across request |
| maxImagesPerRequest | Nullable positive integer, images across all messages |
| maxBytesPerImage | Nullable positive integer, image payload bytes (after Base64 decoding, not decompressed pixels) |

Null maxima mean **no bound declared in this profile**. They do not cause
undetermined on their own, and do not grant unlimited runtime resources. Apply
only declared bounds; when both profiles have one, the lower bound wins.
Zero, negative and non-integer maxima fail structurally. Unknown set members fail;
duplicate members collapse as in the original descriptor capability set.
Image-specific fields must be null/absent without declared image input. Explicit
empty image allowlists with image input are valid restrictive declarations.

Illustrative declaration, not a Gemma/llamadart support claim:

```json
{
  "inputModalities":["image","text"],
  "outputModalities":["text"],
  "inputRoles":["user"],
  "imageSourceTypes":["inlineBytes","localFile"],
  "imageMimeTypes":["image/jpeg","image/png"],
  "maxMessagesPerRequest":null,
  "maxImagesPerRequest":2,
  "maxBytesPerImage":1048576
}
```

## Pure assessment and runtime boundary

Call `assessAiContentCompatibility(request: ..., modelCapabilities: ...,
backendCapabilities: ...)`. Both profiles are explicit caller inputs. Neither
is discovered from modelId; the core checks both, never unions permissions.
Checks cover part modalities, required text output, message roles, image source
and MIME, message/image counts, and inline payload lengths for declared maxima.

The immutable `ModelAiContentCompatibility` report requires `status` and ordered
`reasons`. Status precedence is unsupported > undetermined > meetsDeclaredConstraints.
Reasons must be empty for meeting declarations and nonempty/nonblank otherwise.
They are diagnostic strings, not stable provider codes. Ordering is model before
backend, then profile-table fields, then ascending message/part indexes.

| Situation | Assessment |
| --- | --- |
| Known modality/role/source/MIME/bound denial | unsupported, even with other unknown checks |
| Missing profile or relevant unknown allowlist | undetermined unless a denial wins |
| Null maximum | No bound to check; does not alone cause undetermined |
| Local file and non-null byte maximum | undetermined size check; requires IO |
| Local file and null byte maximum | No size check; the other declarations can match |
| No images supplied | Image-only fields are irrelevant |
| All relevant support declarations known and all declared restrictions pass | meetsDeclaredConstraints |

For example, two text profiles declaring text input/output and user role with all
maxima null match a single user text request. A local-file image with matching
allowlists and a declared byte maximum yields:

```json
{"status":"undetermined","reasons":["model profile.maxBytesPerImage: messages[0].parts[1].source: byte size requires IO"]}
```

Meeting declarations does not prove specific combinations/orderings, codecs,
encoder availability, native option ranges, dimensions, available memory or
successful execution. The provider still checks actual support. Tokenization,
per-role modality matrices and dimensions have no speculative schema here.

Construction, serialization, copies, equality, hashing and assessment never use
disk/network, image codecs, provider runtimes, downloads/cache, global registries
or injected resolvers. Base64 and byte lengths are pure. The core imports no
dart:io, FFI, Flutter or provider package. Applications own path/access/locality
checks, file size/readability, actual MIME/image decoding and runtime execution.
Descriptive metadata cannot supply a measured file size or override a restriction.

Valid but unsupported content returns `AiFailureResult<ModelAiResponse>` with
`ModelAiFailure` code `unsupportedCapability`. A known unchanged incompatibility
is not retryable. No dropping/stringifying images or text-only success is allowed.

```json
{"code":"unsupportedCapability","message":"Image input is not supported by the selected backend.","retryable":false}
```

Unknown support is not malformed input or proven incompatibility. A caller may
perform permitted runtime checks or conservatively decline with a message that
support is not established. A matching declaration followed by runtime feature
rejection still uses unsupportedCapability. Other existing request-policy,
load/inference/resource failures retain their categories. `AiResult` itself is
not a JSON envelope. No HTTP policy enters the core.

## Companion textual consumer and evidence (#10)

Companion [issue #10](https://github.com/grupo-jocaagura/jocaagura_ia/issues/10)
tracks the separately reviewable `packages/jocaagura_ai_server` migration. It uses explicit
text construction/extraction and rejects images or multiple parts before resource
access with unsupportedCapability (the existing HTTP mapping gives 422). Its
other text role/option limits retain their existing invalidRequest behavior.
Legacy textual HTTP bodies remain readable; new examples emit canonical parts.
No model loading, native image execution or new HTTP feature is introduced.

Tests cover structural errors, legacy normalization, canonical JSON text round
trips, all variants, byte/source/MIME rules, deep immutability and copy semantics,
profile set/null/bound rules, restrictive intersection, deterministic reports,
unknown size, and fake-gateway rejection before execution. They separately show
that a matching declaration can still be rejected by a fake runtime. Domain
fixtures require no files, models, networking or native libraries. Core coverage
and server fake-based coverage are measured separately; neither certifies images.
The committed prior text-only POC evidence remains historical and unchanged.
