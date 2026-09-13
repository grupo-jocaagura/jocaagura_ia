import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:jocaagura_ai/jocaagura_ai.dart';
import 'package:jocaagura_ai_server/src/api/inference_handler.dart';
import 'package:jocaagura_ai_server/src/application/poc_application.dart';
import 'package:jocaagura_ai_server/src/infrastructure/local_ai_gateway.dart';
import 'package:llamadart/llamadart.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

class MockEngine extends Mock implements LlamaEngine {}

BackendPerfContextData metrics({int input = 6, int output = 2}) =>
    BackendPerfContextData(
      loadMs: 0,
      promptEvalMs: 0,
      evalMs: 0,
      sampleMs: 0,
      promptEvalTokens: input,
      evalTokens: output,
      sampleCount: output,
      reusedGraphs: 0,
    );

LlamaCompletionChunk chunk({
  String? text,
  String? reason,
  String? thinking,
  List<LlamaCompletionChunkToolCall>? tools,
}) => LlamaCompletionChunk(
  id: 'native-id',
  object: 'chat.completion.chunk',
  created: 0,
  model: 'native-model',
  choices: <LlamaCompletionChunkChoice>[
    LlamaCompletionChunkChoice(
      index: 0,
      delta: LlamaCompletionChunkDelta(
        content: text,
        thinking: thinking,
        toolCalls: tools,
      ),
      finishReason: reason,
    ),
  ],
);

void expectFailure(AiResult<ModelAiResponse> result, EnumAiFailureCode code) {
  expect(result, isA<AiFailureResult<ModelAiResponse>>());
  expect((result as AiFailureResult<ModelAiResponse>).failure.code, code);
}

void main() {
  late Directory directory;
  late File model;
  late MockEngine engine;
  late LocalAiGateway gateway;

  setUpAll(() {
    registerFallbackValue(const ModelParams());
    registerFallbackValue(const GenerationParams());
    registerFallbackValue(<LlamaChatMessage>[]);
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('jocaagura-gateway-');
    model = await File('${directory.path}/test.litertlm')
        .writeAsString('fixture');
    engine = MockEngine();
    when(() => engine.setLogLevel(LlamaLogLevel.error))
        .thenAnswer((_) async {});
    when(() => engine.loadModel(any(), modelParams: any(named: 'modelParams')))
        .thenAnswer((_) async {});
    when(() => engine.dispose()).thenAnswer((_) async {});
    when(() => engine.getPerformanceContext())
        .thenAnswer((_) async => metrics());
    when(
      () => engine.create(
        any(),
        params: any(named: 'params'),
        enableThinking: false,
      ),
    ).thenAnswer(
      (_) => Stream<LlamaCompletionChunk>.fromIterable(<LlamaCompletionChunk>[
        chunk(text: ' O'),
        chunk(text: 'K\n'),
        chunk(reason: 'stop'),
      ]),
    );
    gateway = LocalAiGateway(modelPath: model.path, createEngine: () => engine);
  });

  tearDown(() async {
    await gateway.close();
    await directory.delete(recursive: true);
  });

  test(
    'preserves text/IDs, native counts and deterministic CPU settings',
    () async {
      final ModelAiResponse response = (await gateway.infer(
        smokeRequest(),
      ) as AiSuccess<ModelAiResponse>).value;
      expect(response.text, ' OK\n');
      expect(response.requestId, 'offline-poc-1');
      expect(response.modelId, LocalAiGateway.modelId);
      expect(response.finishReason, EnumAiFinishReason.completed);
      expect(response.usage, ModelAiUsage(inputTokens: 6, outputTokens: 2));
      expect(response.usage!.totalTokens, isNull);
      final List<dynamic> generation = verify(
        () => engine.create(
          captureAny(),
          params: captureAny(named: 'params'),
          enableThinking: false,
        ),
      ).captured;
      final List<LlamaChatMessage> messages =
          generation[0] as List<LlamaChatMessage>;
      expect(messages.single.role, LlamaChatRole.user);
      final GenerationParams params = generation[1] as GenerationParams;
      expect(params.maxTokens, 32);
      expect(params.temp, 0);
      expect(params.topK, 1);
      expect(params.seed, 42);
      final ModelParams load =
          verify(
                () => engine.loadModel(
                  model.absolute.path,
                  modelParams: captureAny(named: 'modelParams'),
                ),
              ).captured.single
              as ModelParams;
      expect(load.liteRtLmBackend, LiteRtLmBackendPreference.cpu);
      expect(load.contextSize, 2048);
      verify(() => engine.dispose()).called(1);
    },
  );

  test(
    'applies nullable option defaults and honors a smaller output budget',
    () async {
      await gateway.infer(
        smokeRequest().copyWith(options: ModelAiGenerationOptions()),
      );
      when(() => engine.getPerformanceContext())
          .thenAnswer((_) async => metrics(output: 1));
      final AiResult<ModelAiResponse> result = await gateway.infer(
        smokeRequest().copyWith(
          options: ModelAiGenerationOptions(maxOutputTokens: 1),
        ),
      );
      expect(
        (result as AiSuccess<ModelAiResponse>).value.finishReason,
        EnumAiFinishReason.outputLimit,
      );
      expect(smokePassed(result), isFalse);
    },
  );

  test('unknown ID rejects without loading', () async {
    expectFailure(
      await gateway.infer(smokeRequest().copyWith(modelId: 'other')),
      EnumAiFailureCode.modelUnavailable,
    );
    verifyNever(
      () => engine.loadModel(any(), modelParams: any(named: 'modelParams')),
    );
  });

  test('companion migration rejects images and multipart input before resource access', () async {
    await model.delete(); // Rejection must precede even opening the model file.
    int engineCreations = 0;
    final LocalAiGateway migrated = LocalAiGateway(
      modelPath: model.path,
      createEngine: () {
        engineCreations++;
        return engine;
      },
    );
    addTearDown(migrated.close);
    final ModelAiTextPart text = ModelAiTextPart(text: 'Describe:');
    final ModelAiImagePart image = ModelAiImagePart(
      mimeType: 'image/png',
      source: ModelAiLocalFileSource(path: 'does-not-exist.png'),
    );
    for (final List<ModelAiContentPart> parts in <List<ModelAiContentPart>>[
      <ModelAiContentPart>[image],
      <ModelAiContentPart>[text, image, text],
      <ModelAiContentPart>[text, text],
    ]) {
      final ModelAiRequest request = smokeRequest().copyWith(
        messages: <ModelAiMessage>[
          ModelAiMessage(role: EnumAiMessageRole.user, parts: parts),
        ],
      );
      final AiResult<ModelAiResponse> result = await migrated.infer(request);
      expectFailure(result, EnumAiFailureCode.unsupportedCapability);
      expect(
        (result as AiFailureResult<ModelAiResponse>).failure.retryable,
        isFalse,
      );
      final Response response = await inferenceHandler(migrated)(
        Request(
          'POST',
          Uri.parse('http://localhost/v1/inference'),
          body: jsonEncode(request.toJson()),
        ),
      );
      expect(response.statusCode, 422);
    }
    expect(engineCreations, 0);
    verifyNever(
      () => engine.loadModel(any(), modelParams: any(named: 'modelParams')),
    );
  });

  test(
    'unsupported request shapes/options are rejected before engine use',
    () async {
      final ModelAiRequest request = smokeRequest();
      for (final ModelAiRequest invalid in <ModelAiRequest>[
        request.copyWith(
          messages: <ModelAiMessage>[...request.messages, ...request.messages],
        ),
        request.copyWith(
          messages: <ModelAiMessage>[
            ModelAiMessage.text(role: EnumAiMessageRole.system, text: 'x'),
          ],
        ),
        request.copyWith(
          messages: <ModelAiMessage>[
            ModelAiMessage.text(role: EnumAiMessageRole.assistant, text: 'x'),
          ],
        ),
        request.copyWith(
          messages: <ModelAiMessage>[
            ModelAiMessage.text(role: EnumAiMessageRole.user, text: 'x' * 4097),
          ],
        ),
        request.copyWith(
          options: ModelAiGenerationOptions(maxOutputTokens: 129),
        ),
        request.copyWith(options: ModelAiGenerationOptions(temperature: 0.5)),
        request.copyWith(
          options: ModelAiGenerationOptions(stopSequences: <String>['stop']),
        ),
      ]) {
        expectFailure(
          await gateway.infer(invalid),
          EnumAiFailureCode.invalidRequest,
        );
      }
      verifyNever(
        () => engine.loadModel(any(), modelParams: any(named: 'modelParams')),
      );
    },
  );

  test('accepts boundary sizes', () async {
    final AiResult<ModelAiResponse> result = await gateway.infer(
      smokeRequest().copyWith(
        messages: <ModelAiMessage>[
          ModelAiMessage.text(role: EnumAiMessageRole.user, text: 'x' * 4096),
        ],
        options: ModelAiGenerationOptions(maxOutputTokens: 128),
      ),
    );
    expect(result, isA<AiSuccess<ModelAiResponse>>());
  });

  test('missing file maps to unavailable without creating runtime', () async {
    await model.delete();
    expectFailure(
      await gateway.infer(smokeRequest()),
      EnumAiFailureCode.modelUnavailable,
    );
    verifyNever(() => engine.dispose());
  });

  test(
    'failed load maps and disposes before allowing another request',
    () async {
      when(
        () => engine.loadModel(any(), modelParams: any(named: 'modelParams')),
      ).thenThrow(LlamaModelException('private native details'));
      expectFailure(
        await gateway.infer(smokeRequest()),
        EnumAiFailureCode.modelLoadFailure,
      );
      verify(() => engine.dispose()).called(1);
      when(
        () => engine.loadModel(any(), modelParams: any(named: 'modelParams')),
      ).thenAnswer((_) async {});
      expect(
        await gateway.infer(smokeRequest()),
        isA<AiSuccess<ModelAiResponse>>(),
      );
    },
  );

  test('native initialization failure maps to load failure', () async {
    when(() => engine.setLogLevel(LlamaLogLevel.error))
        .thenThrow(LlamaBackendInitializationException('private path'));
    expectFailure(
      await gateway.infer(smokeRequest()),
      EnumAiFailureCode.modelLoadFailure,
    );
    verify(() => engine.dispose()).called(1);
  });

  test(
    'native inference/unsupported failures dispose and never expose details',
    () async {
      for (final LlamaException error in <LlamaException>[
        LlamaInferenceException('secret file'),
        LlamaUnsupportedException('private detail'),
      ]) {
        when(
          () => engine.create(
            any(),
            params: any(named: 'params'),
            enableThinking: false,
          ),
        ).thenAnswer((_) => Stream<LlamaCompletionChunk>.error(error));
        final AiResult<ModelAiResponse> result = await gateway.infer(
          smokeRequest(),
        );
        expectFailure(
          result,
          error is LlamaUnsupportedException
              ? EnumAiFailureCode.unsupportedCapability
              : EnumAiFailureCode.inferenceFailure,
        );
        expect(
          (result as AiFailureResult<ModelAiResponse>).failure.message,
          isNot(contains('private')),
        );
      }
      verify(() => engine.dispose()).called(2);
    },
  );

  test(
    'rejects missing/unknown terminal markers and malformed completion streams',
    () async {
      for (final List<LlamaCompletionChunk> chunks
          in <List<LlamaCompletionChunk>>[
            <LlamaCompletionChunk>[],
            <LlamaCompletionChunk>[chunk(text: 'OK')],
            <LlamaCompletionChunk>[chunk(reason: 'length')],
            <LlamaCompletionChunk>[
              chunk(reason: 'stop'),
              chunk(text: 'after end'),
            ],
            <LlamaCompletionChunk>[
              LlamaCompletionChunk(
                id: 'x',
                object: 'x',
                created: 0,
                model: 'x',
                choices: <LlamaCompletionChunkChoice>[],
              ),
            ],
          ]) {
        when(
          () => engine.create(
            any(),
            params: any(named: 'params'),
            enableThinking: false,
          ),
        ).thenAnswer((_) => Stream<LlamaCompletionChunk>.fromIterable(chunks));
        expectFailure(
          await gateway.infer(smokeRequest()),
          EnumAiFailureCode.inferenceFailure,
        );
      }
    },
  );

  test(
    'rejects thinking and tool output without deleting it to pass the POC',
    () async {
      for (final LlamaCompletionChunk unexpected in <LlamaCompletionChunk>[
        chunk(text: 'OK', thinking: 'reasoning'),
        chunk(
          tools: <LlamaCompletionChunkToolCall>[
            LlamaCompletionChunkToolCall(index: 0),
          ],
        ),
      ]) {
        when(
          () => engine.create(
            any(),
            params: any(named: 'params'),
            enableThinking: false,
          ),
        ).thenAnswer((_) => Stream<LlamaCompletionChunk>.value(unexpected));
        expectFailure(
          await gateway.infer(smokeRequest()),
          EnumAiFailureCode.unsupportedCapability,
        );
      }
    },
  );

  test(
    'missing/invalid metrics fail rather than fabricate finish or usage',
    () async {
      for (final BackendPerfContextData? invalid in <BackendPerfContextData?>[
        null,
        metrics(input: -1),
        metrics(output: -1),
      ]) {
        when(() => engine.getPerformanceContext())
            .thenAnswer((_) async => invalid);
        expectFailure(
          await gateway.infer(smokeRequest()),
          EnumAiFailureCode.inferenceFailure,
        );
      }
    },
  );

  test(
    'cleanup failure cannot report success or replace the original failure',
    () async {
      when(() => engine.dispose())
          .thenThrow(LlamaStateException('dispose failed'));
      expectFailure(
        await gateway.infer(smokeRequest()),
        EnumAiFailureCode.inferenceFailure,
      );
      when(
        () => engine.loadModel(any(), modelParams: any(named: 'modelParams')),
      ).thenThrow(LlamaModelException('load failed'));
      expectFailure(
        await gateway.infer(smokeRequest()),
        EnumAiFailureCode.modelLoadFailure,
      );
    },
  );

  test(
    'programming errors propagate after cleanup and release busy state',
    () async {
      when(() => engine.getPerformanceContext()).thenThrow(StateError('bug'));
      await expectLater(gateway.infer(smokeRequest()), throwsStateError);
      verify(() => engine.dispose()).called(1);
      when(() => engine.getPerformanceContext())
          .thenAnswer((_) async => metrics());
      expect(
        await gateway.infer(smokeRequest()),
        isA<AiSuccess<ModelAiResponse>>(),
      );
    },
  );

  test(
    'close waits for active work; busy and closed reject without cancellation',
    () async {
      final Completer<void> loading = Completer<void>();
      final Completer<void> entered = Completer<void>();
      when(
        () => engine.loadModel(any(), modelParams: any(named: 'modelParams')),
      ).thenAnswer((_) {
        entered.complete();
        return loading.future;
      });
      final Future<AiResult<ModelAiResponse>> first = gateway.infer(
        smokeRequest(),
      );
      await entered.future;
      expectFailure(
        await gateway.infer(smokeRequest()),
        EnumAiFailureCode.invalidRequest,
      );
      bool closed = false;
      final Future<void> closing = gateway.close().then((_) {
        closed = true;
      });
      await Future<void>.delayed(Duration.zero);
      expect(closed, isFalse);
      loading.complete();
      expect(await first, isA<AiSuccess<ModelAiResponse>>());
      await closing;
      expect(closed, isTrue);
      expectFailure(
        await gateway.infer(smokeRequest()),
        EnumAiFailureCode.invalidRequest,
      );
      await gateway.close();
      verify(() => engine.dispose()).called(1);
    },
  );

  test(
    'local path validation rejects URLs, blank and other artifact formats',
    () {
      for (final String path in <String>[
        '',
        ' ',
        'https://host/model.litertlm',
        'model.gguf',
      ]) {
        expect(() => LocalAiGateway(modelPath: path), throwsArgumentError);
      }
    },
  );

  test(
    'shared composition drives direct and HTTP paths through the same gateway',
    () async {
      final PocApplication app = PocApplication.withGateway(gateway);
      expect(smokePassed(await app.smoke()), isTrue);
      final Response response = await app.handler(
        Request(
          'POST',
          Uri.parse('http://localhost/v1/inference'),
          body: jsonEncode(smokeRequest().toJson()),
        ),
      );
      expect(response.statusCode, 200);
      expect(
        ModelAiResponse.fromJson(
          jsonDecode(await response.readAsString()) as Map<String, dynamic>,
        ).text,
        ' OK\n',
      );
      verify(() => engine.dispose()).called(2);
      await app.close();
    },
  );

  test(
    'local composition handles missing resources without a native engine',
    () async {
      final PocApplication app = PocApplication.local(
        '${directory.path}/missing.litertlm',
      );
      final AiResult<ModelAiResponse> result = await app.smoke();
      expectFailure(result, EnumAiFailureCode.modelUnavailable);
      expect(smokePassed(result), isFalse);
      await app.close();
    },
  );

  test(
    'smoke requires exact answer and IDs, without rewriting the response',
    () {
      final ModelAiResponse ok = ModelAiResponse(
        requestId: 'offline-poc-1',
        modelId: LocalAiGateway.modelId,
        text: 'OK',
        finishReason: EnumAiFinishReason.completed,
      );
      for (final ModelAiResponse wrong in <ModelAiResponse>[
        ok.copyWith(requestId: 'wrong'),
        ok.copyWith(modelId: 'wrong'),
        ok.copyWith(text: 'OK, done'),
        ok.copyWith(text: ''),
        ok.copyWith(finishReason: EnumAiFinishReason.outputLimit),
      ]) {
        expect(smokePassed(AiSuccess<ModelAiResponse>(wrong)), isFalse);
      }
    },
  );
}
