import 'package:jocaagura_ai/jocaagura_ai.dart';
import 'package:shelf/shelf.dart';

import '../api/inference_handler.dart';
import '../infrastructure/local_ai_gateway.dart';

/// Shared composition for the HTTP server and socket-free smoke command.
final class PocApplication {
  PocApplication.local(String modelPath)
    : this.withGateway(LocalAiGateway(modelPath: modelPath));

  PocApplication.withGateway(LocalAiGateway gateway)
    : _gateway = gateway,
      handler = inferenceHandler(gateway);

  final LocalAiGateway _gateway;
  final Handler handler;

  Future<AiResult<ModelAiResponse>> smoke() => _gateway.infer(smokeRequest());

  Future<void> close() => _gateway.close();
}

ModelAiRequest smokeRequest() => ModelAiRequest(
  requestId: 'offline-poc-1',
  modelId: LocalAiGateway.modelId,
  messages: <ModelAiMessage>[
    ModelAiMessage(
      role: EnumAiMessageRole.user,
      content: 'Respond only with OK',
    ),
  ],
  options: ModelAiGenerationOptions(
    maxOutputTokens: LocalAiGateway.defaultOutputTokens,
    temperature: 0,
  ),
);

bool smokePassed(AiResult<ModelAiResponse> result) => switch (result) {
  AiSuccess<ModelAiResponse>(value: final ModelAiResponse value) =>
    value.requestId == 'offline-poc-1' &&
        value.modelId == LocalAiGateway.modelId &&
        value.finishReason == EnumAiFinishReason.completed &&
        value.text.trim() == 'OK',
  AiFailureResult<ModelAiResponse>() => false,
};
