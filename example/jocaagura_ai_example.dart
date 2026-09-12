import 'dart:convert';
import 'dart:io';

import 'package:jocaagura_ai/jocaagura_ai.dart';

/// Demonstrates immutable JSON contracts with a fixture, not real inference.
void main() {
  final ModelAiRequest request = ModelAiRequest(
    requestId: 'example-request',
    modelId: 'local-demo',
    messages: <ModelAiMessage>[
      ModelAiMessage(
        role: EnumAiMessageRole.user,
        content: 'Respond only with OK',
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
}
