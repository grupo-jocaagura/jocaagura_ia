import 'dart:async';
import 'dart:io';

import 'package:jocaagura_ia/jocaagura_ia.dart';
import 'package:llamadart/llamadart.dart';

/// One local LiteRT-LM session per request, owned entirely by this adapter.
///
/// This deliberately supports a single user message and CPU text generation.
/// The optional engine factory is an infrastructure testing seam, not a domain
/// dependency. No runtime object crosses the AiGateway request/result boundary.
final class LocalAiGateway implements AiGateway {
  LocalAiGateway({
    required String modelPath,
    LlamaEngine Function()? createEngine,
  }) : _modelPath = File(modelPath).absolute.path,
       _createEngine = createEngine ?? _newEngine {
    if (modelPath.trim().isEmpty ||
        modelPath.contains('://') ||
        !modelPath.endsWith('.litertlm')) {
      throw ArgumentError('Expected a local .litertlm file path.');
    }
  }

  static const String modelId = 'gemma-4-e2b-poc';
  static const int defaultOutputTokens = 32;
  final String _modelPath;
  final LlamaEngine Function() _createEngine;
  Completer<void>? _active;
  bool _closed = false;

  static LlamaEngine _newEngine() => LlamaEngine(LlamaBackend());

  @override
  Future<AiResult<ModelAiResponse>> infer(ModelAiRequest request) async {
    if (_closed || _active != null) {
      return _failure(
        EnumAiFailureCode.invalidRequest,
        'Gateway closed or busy.',
      );
    }
    if (request.modelId != modelId) {
      return _failure(EnumAiFailureCode.modelUnavailable, 'Unknown model ID.');
    }
    if (request.messages.length != 1 ||
        request.messages.single.role != EnumAiMessageRole.user ||
        request.messages.single.content.length > 4096 ||
        (request.options.maxOutputTokens ?? defaultOutputTokens) > 128 ||
        (request.options.temperature ?? 0) != 0 ||
        request.options.stopSequences.isNotEmpty) {
      return _failure(
        EnumAiFailureCode.invalidRequest,
        'Supported: one user message up to 4096 characters, output limit 1..128, '
        'temperature 0 (greedy), no custom stop sequences.',
      );
    }

    final Completer<void> active = Completer<void>();
    _active = active;
    LlamaEngine? engine;
    bool loaded = false;
    AiResult<ModelAiResponse>? result;
    try {
      // Verify readability before the engine is allocated; no URL resolver or
      // download/cache API participates in inference.
      final RandomAccessFile file = await File(_modelPath).open();
      await file.close();
      engine = _createEngine();
      await engine.setLogLevel(LlamaLogLevel.error);
      await engine.loadModel(
        _modelPath,
        modelParams: const ModelParams(
          contextSize: 2048,
          numberOfThreads: 4,
          liteRtLmBackend: LiteRtLmBackendPreference.cpu,
        ),
      );
      loaded = true;
      final int limit = request.options.maxOutputTokens ?? defaultOutputTokens;
      final StringBuffer text = StringBuffer();
      String? terminalReason;
      await for (final LlamaCompletionChunk chunk in engine.create(
        <LlamaChatMessage>[
          LlamaChatMessage.fromText(
            role: LlamaChatRole.user,
            text: request.messages.single.content,
          ),
        ],
        params: GenerationParams(
          maxTokens: limit,
          temp: request.options.temperature ?? 0,
          topK: 1,
          topP: 1,
          seed: 42,
        ),
        enableThinking: false,
      )) {
        if (chunk.choices.length != 1 || terminalReason != null) {
          throw LlamaInferenceException('Unexpected completion stream.');
        }
        final LlamaCompletionChunkChoice choice = chunk.choices.single;
        if ((choice.delta.toolCalls?.isNotEmpty ?? false) ||
            (choice.delta.thinking?.isNotEmpty ?? false)) {
          throw LlamaUnsupportedException('Non-text output is not supported.');
        }
        text.write(choice.delta.content ?? '');
        terminalReason = choice.finishReason;
      }
      // 0.8.23's chat parser emits "stop" even when the native output budget
      // was reached. Use native decode counts; never count text chunks/tokens
      // by splitting strings, or assume "stop" proves natural completion.
      final BackendPerfContextData? metrics = await engine
          .getPerformanceContext();
      if (terminalReason != 'stop' ||
          metrics == null ||
          metrics.evalTokens < 0 ||
          metrics.promptEvalTokens < 0) {
        throw LlamaInferenceException('Missing reliable terminal diagnostics.');
      }
      result = AiSuccess<ModelAiResponse>(
        ModelAiResponse(
          requestId: request.requestId,
          modelId: request.modelId,
          text: text.toString(),
          finishReason: metrics.evalTokens >= limit
              ? EnumAiFinishReason.outputLimit
              : EnumAiFinishReason.completed,
          usage: ModelAiUsage(
            inputTokens: metrics.promptEvalTokens,
            outputTokens: metrics.evalTokens,
          ),
        ),
      );
    } on FileSystemException {
      result = _failure(
        EnumAiFailureCode.modelUnavailable,
        'Local model file is unavailable or unreadable.',
      );
    } on LlamaUnsupportedException {
      result = _failure(
        EnumAiFailureCode.unsupportedCapability,
        'The selected runtime does not support this operation.',
      );
    } on LlamaException {
      result = _failure(
        loaded
            ? EnumAiFailureCode.inferenceFailure
            : EnumAiFailureCode.modelLoadFailure,
        loaded
            ? 'Local inference failed.'
            : 'Local model/runtime loading failed.',
      );
    } finally {
      try {
        await engine?.dispose();
      } on LlamaException {
        // A failed cleanup must not turn an existing failure into success.
        if (result is AiSuccess<ModelAiResponse>) {
          result = _failure(
            EnumAiFailureCode.inferenceFailure,
            'Local session cleanup failed.',
          );
        }
      } finally {
        _active = null;
        active.complete();
      }
    }
    // Unexpected programming errors propagate after cleanup.
    return result!;
  }

  /// Rejects new requests and waits for active work and cleanup, without cancel.
  Future<void> close() async {
    _closed = true;
    await _active?.future;
  }

  static AiFailureResult<ModelAiResponse> _failure(
    EnumAiFailureCode code,
    String message,
  ) => AiFailureResult<ModelAiResponse>(
    ModelAiFailure(code: code, message: message),
  );
}
