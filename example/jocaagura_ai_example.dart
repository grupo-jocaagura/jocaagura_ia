import 'dart:convert';
import 'dart:io';

import 'package:jocaagura_ai/jocaagura_ai.dart';

/// Demonstrates immutable JSON contracts with a fixture, not real inference.
void main() {
  final ModelAiRequest request = ModelAiRequest(
    requestId: 'example-request',
    modelId: 'local-demo',
    messages: <ModelAiMessage>[
      ModelAiMessage.text(
        role: EnumAiMessageRole.user,
        text: 'Respond only with OK',
      ),
    ],
    options: ModelAiGenerationOptions(maxOutputTokens: 8),
  );
  final String encoded = jsonEncode(request.toJson());
  final ModelAiRequest restored = ModelAiRequest.fromJson(
    jsonDecode(encoded) as Map<String, dynamic>,
  );
  final ModelAiRequest updated = restored.copyWith(
    requestId: 'another-request',
    options: restored.options.copyWith(maxOutputTokens: null),
  );
  final AiResult<ModelAiResponse> fixture = AiSuccess<ModelAiResponse>(
    ModelAiResponse(
      requestId: updated.requestId,
      modelId: updated.modelId,
      text: 'OK',
      finishReason: EnumAiFinishReason.completed,
    ),
  );
  final Map<String, dynamic> json = switch (fixture) {
    AiSuccess<ModelAiResponse>(:final ModelAiResponse value) => value.toJson(),
    AiFailureResult<ModelAiResponse>(:final ModelAiFailure failure) =>
      failure.toJson(),
  };
  stdout.writeln(jsonEncode(json));

  // An input declaration, not a valid image or a real inference request.
  final ModelAiRequest mixed = request.copyWith(
    messages: <ModelAiMessage>[
      ModelAiMessage(
        role: EnumAiMessageRole.user,
        parts: <ModelAiContentPart>[
          ModelAiTextPart(text: 'Describe:'),
          ModelAiImagePart(
            mimeType: 'image/png',
            source: ModelAiInlineBytesSource(bytes: <int>[1, 2, 3]),
          ),
        ],
      ),
    ],
  );
  final ModelAiContentCapabilities imageDeclaration =
      ModelAiContentCapabilities(
        inputModalities: EnumAiInputModality.values.toSet(),
        outputModalities: <EnumAiOutputModality>{EnumAiOutputModality.text},
        inputRoles: <EnumAiMessageRole>{EnumAiMessageRole.user},
        imageSourceTypes: <EnumAiContentSourceType>{
          EnumAiContentSourceType.inlineBytes,
        },
        imageMimeTypes: <String>{'image/png'},
      );
  final ModelAiContentCapabilities textDeclaration = ModelAiContentCapabilities(
    inputModalities: <EnumAiInputModality>{EnumAiInputModality.text},
    outputModalities: <EnumAiOutputModality>{EnumAiOutputModality.text},
    inputRoles: <EnumAiMessageRole>{EnumAiMessageRole.user},
  );
  final ModelAiContentCompatibility assessment = assessAiContentCompatibility(
    request: mixed,
    modelCapabilities: imageDeclaration,
    backendCapabilities: textDeclaration,
  );
  stdout.writeln(jsonEncode(mixed.toJson()));
  stdout.writeln(jsonEncode(assessment.toJson())); // unsupported, without IO.
}
