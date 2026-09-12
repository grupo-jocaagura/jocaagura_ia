import 'dart:convert';

import 'package:jocaagura_ia/jocaagura_ia.dart';
import 'package:test/test.dart';

final String sha = List<String>.filled(64, 'a').join();
ModelAiMessage message([String content = 'Respond only with OK']) =>
    ModelAiMessage(role: EnumAiMessageRole.user, content: content);
ModelAiSource source() => ModelAiSource.localFile(path: '/models/demo.bin');
ModelAiFailure failure() => ModelAiFailure(
  code: EnumAiFailureCode.modelLoadFailure,
  message: 'Unable to load the model',
);
ModelAiDescriptor descriptor() => ModelAiDescriptor(
  id: 'demo',
  displayName: 'Demo',
  version: 'revision-a',
  capabilities: <EnumAiCapability>{EnumAiCapability.textGeneration},
  requirements: ModelAiRequirements(storageBytes: 42, minimumMemoryBytes: 128),
  source: source(),
);

void valueContract<T extends Object>(
  String name, {
  required T value,
  required Map<String, dynamic> Function(T) encode,
  required T Function(Map<String, dynamic>) decode,
  required T Function(T) copy,
  required List<T> changed,
}) {
  group(name, () {
    test('survives actual JSON text encoding and decoding', () {
      final String json = jsonEncode(encode(value));
      final T restored = decode(jsonDecode(json) as Map<String, dynamic>);
      expect(restored, value);
      expect(restored.hashCode, value.hashCode);
      expect(jsonEncode(encode(restored)), json);
      expect(<T>{value, restored}, hasLength(1));
    });
    test('copy preserves values and equality is type-safe', () {
      final T copied = copy(value);
      expect(copied, value);
      expect(copied.hashCode, value.hashCode);
      expect(identical(copied, value), isFalse);
      expect(value, equals(value));
      expect(value, isNot(equals(Object())));
      for (final T alternative in changed) {
        expect(alternative, isNot(equals(value)));
        expect(value, isNot(equals(alternative)));
      }
    });
    test('unknown object keys are ignored', () {
      final Map<String, dynamic> json = encode(value)..['futureField'] = true;
      expect(decode(json), value);
    });
  });
}

void main() {
  final ModelAiMessage msg = message();
  final ModelAiGenerationOptions options = ModelAiGenerationOptions(
    maxOutputTokens: 10,
    temperature: 0.5,
    stopSequences: <String>['END'],
  );
  final ModelAiRequest request = ModelAiRequest(
    requestId: 'r1',
    modelId: 'demo',
    messages: <ModelAiMessage>[msg],
    options: options,
  );
  final ModelAiUsage usage = ModelAiUsage(
    inputTokens: 1,
    outputTokens: 2,
    totalTokens: 9,
  );
  final ModelAiResponse response = ModelAiResponse(
    requestId: 'r1',
    modelId: 'demo',
    text: 'OK',
    finishReason: EnumAiFinishReason.completed,
    usage: usage,
  );
  final ModelAiRequirements requirements = ModelAiRequirements(
    storageBytes: 10,
    minimumMemoryBytes: 20,
  );
  final ModelAiDescriptor model = descriptor();
  final ModelAiFailure error = failure();
  final ModelAiState state = ModelAiState(
    modelId: 'demo',
    status: EnumAiModelStatus.failed,
    progress: 0.5,
    failure: error,
  );
  valueContract(
    'message',
    value: msg,
    encode: (ModelAiMessage v) => v.toJson(),
    decode: ModelAiMessage.fromJson,
    copy: (ModelAiMessage v) => v.copyWith(),
    changed: <ModelAiMessage>[
      msg.copyWith(role: EnumAiMessageRole.assistant),
      msg.copyWith(content: 'Another message'),
    ],
  );
  valueContract(
    'options',
    value: options,
    encode: (ModelAiGenerationOptions v) => v.toJson(),
    decode: ModelAiGenerationOptions.fromJson,
    copy: (ModelAiGenerationOptions v) => v.copyWith(),
    changed: <ModelAiGenerationOptions>[
      options.copyWith(maxOutputTokens: 20),
      options.copyWith(temperature: 1.0),
      options.copyWith(stopSequences: <String>['STOP']),
      options.copyWith(stopSequences: <String>[]),
    ],
  );
  valueContract(
    'request',
    value: request,
    encode: (ModelAiRequest v) => v.toJson(),
    decode: ModelAiRequest.fromJson,
    copy: (ModelAiRequest v) => v.copyWith(),
    changed: <ModelAiRequest>[
      request.copyWith(requestId: 'r2'),
      request.copyWith(modelId: 'other'),
      request.copyWith(messages: <ModelAiMessage>[message('New')]),
      request.copyWith(options: options.copyWith(temperature: 1.0)),
    ],
  );
  valueContract(
    'usage',
    value: usage,
    encode: (ModelAiUsage v) => v.toJson(),
    decode: ModelAiUsage.fromJson,
    copy: (ModelAiUsage v) => v.copyWith(),
    changed: <ModelAiUsage>[
      usage.copyWith(inputTokens: 2),
      usage.copyWith(outputTokens: 3),
      usage.copyWith(totalTokens: 10),
    ],
  );
  valueContract(
    'response',
    value: response,
    encode: (ModelAiResponse v) => v.toJson(),
    decode: ModelAiResponse.fromJson,
    copy: (ModelAiResponse v) => v.copyWith(),
    changed: <ModelAiResponse>[
      response.copyWith(requestId: 'r2'),
      response.copyWith(modelId: 'other'),
      response.copyWith(text: ''),
      response.copyWith(finishReason: EnumAiFinishReason.outputLimit),
      response.copyWith(usage: usage.copyWith(totalTokens: 99)),
    ],
  );
  valueContract(
    'requirements',
    value: requirements,
    encode: (ModelAiRequirements v) => v.toJson(),
    decode: ModelAiRequirements.fromJson,
    copy: (ModelAiRequirements v) => v.copyWith(),
    changed: <ModelAiRequirements>[
      requirements.copyWith(storageBytes: 11),
      requirements.copyWith(minimumMemoryBytes: 21),
    ],
  );
  valueContract(
    'descriptor',
    value: model,
    encode: (ModelAiDescriptor v) => v.toJson(),
    decode: ModelAiDescriptor.fromJson,
    copy: (ModelAiDescriptor v) => v.copyWith(),
    changed: <ModelAiDescriptor>[
      model.copyWith(id: 'other'),
      model.copyWith(displayName: 'Other'),
      model.copyWith(version: 'b'),
      model.copyWith(requirements: requirements),
      model.copyWith(
        source: ModelAiSource.bundledAsset(assetPath: 'assets/model.bin'),
      ),
    ],
  );
  valueContract(
    'failure',
    value: error,
    encode: (ModelAiFailure v) => v.toJson(),
    decode: ModelAiFailure.fromJson,
    copy: (ModelAiFailure v) => v.copyWith(),
    changed: <ModelAiFailure>[
      error.copyWith(code: EnumAiFailureCode.inferenceFailure),
      error.copyWith(message: 'Different'),
      error.copyWith(retryable: true),
    ],
  );
  valueContract(
    'state',
    value: state,
    encode: (ModelAiState v) => v.toJson(),
    decode: ModelAiState.fromJson,
    copy: (ModelAiState v) => v.copyWith(),
    changed: <ModelAiState>[
      state.copyWith(modelId: 'other'),
      state.copyWith(status: EnumAiModelStatus.installed, failure: null),
      state.copyWith(progress: 1.0),
      state.copyWith(failure: error.copyWith(retryable: true)),
    ],
  );
  final List<ModelAiSource> sources = <ModelAiSource>[
    source(),
    ModelAiSource.localFile(path: 'relative.bin', expectedSha256: sha),
    ModelAiSource.bundledAsset(assetPath: 'assets/demo.bin'),
    ModelAiSource.remoteDownload(
      url: 'https://example.com/model.bin',
      expectedSha256: sha,
    ),
  ];
  for (int i = 0; i < sources.length; i++) {
    valueContract(
      'source $i',
      value: sources[i],
      encode: (ModelAiSource v) => v.toJson(),
      decode: ModelAiSource.fromJson,
      copy: (ModelAiSource v) => v.copyWith(),
      changed: <ModelAiSource>[ModelAiSource.localFile(path: 'different.bin')],
    );
  }

  test(
    'nullable fields distinguish omission, zero, replacement and clearing',
    () {
      expect(
        options.copyWith(maxOutputTokens: null, temperature: null),
        ModelAiGenerationOptions(stopSequences: <String>['END']),
      );
      expect(
        usage.copyWith(
          inputTokens: null,
          outputTokens: null,
          totalTokens: null,
        ),
        ModelAiUsage(),
      );
      expect(
        requirements.copyWith(storageBytes: null, minimumMemoryBytes: null),
        ModelAiRequirements(),
      );
      expect(state.copyWith(progress: null).progress, isNull);
      expect(response.copyWith(usage: null).usage, isNull);
      expect(
        sources[1].copyWith(expectedSha256: null),
        ModelAiSource.localFile(path: 'relative.bin'),
      );
      final ModelAiSource converted = sources[0].copyWith(
        type: EnumAiSourceType.bundledAsset,
        path: null,
        assetPath: 'assets/file.bin',
      );
      expect(
        converted,
        ModelAiSource.bundledAsset(assetPath: 'assets/file.bin'),
      );
      expect(
        converted.copyWith(
          type: EnumAiSourceType.remoteDownload,
          assetPath: null,
          url: 'https://example.com/m',
          expectedSha256: sha,
        ),
        ModelAiSource.remoteDownload(
          url: 'https://example.com/m',
          expectedSha256: sha,
        ),
      );
      expect(
        sources[3].copyWith(
          type: EnumAiSourceType.localFile,
          url: null,
          path: 'local.bin',
          expectedSha256: null,
        ),
        ModelAiSource.localFile(path: 'local.bin'),
      );
      expect(
        ModelAiUsage(inputTokens: 0, outputTokens: 0, totalTokens: 0),
        isNot(ModelAiUsage()),
      );
      expect(() => usage.copyWith(inputTokens: 'bad'), throwsArgumentError);
      expect(() => state.copyWith(failure: null), throwsArgumentError);
    },
  );

  test(
    'nullable payloads survive text round trips and absent nullable keys',
    () {
      final ModelAiResponse empty = response.copyWith(
        text: '',
        finishReason: EnumAiFinishReason.completed,
        usage: null,
      );
      expect(
        ModelAiResponse.fromJson(
          jsonDecode(jsonEncode(empty.toJson())) as Map<String, dynamic>,
        ),
        empty,
      );
      final ModelAiState initial = ModelAiState(
        modelId: 'demo',
        status: EnumAiModelStatus.notInstalled,
      );
      expect(
        ModelAiState.fromJson(
          jsonDecode(jsonEncode(initial.toJson())) as Map<String, dynamic>,
        ),
        initial,
      );
      expect(ModelAiUsage.fromJson(<String, dynamic>{}), ModelAiUsage());
      expect(
        ModelAiRequirements.fromJson(<String, dynamic>{}),
        ModelAiRequirements(),
      );
      expect(
        ModelAiGenerationOptions.fromJson(<String, dynamic>{}),
        ModelAiGenerationOptions(),
      );
      final Map<String, dynamic> json = empty.toJson()..remove('usage');
      expect(ModelAiResponse.fromJson(json), empty);
      expect(
        ModelAiRequest(
          requestId: 'r',
          modelId: 'demo',
          messages: <ModelAiMessage>[msg],
        ).options,
        ModelAiGenerationOptions(),
      );
    },
  );

  test('input collections and returned JSON cannot mutate models', () {
    final List<ModelAiMessage> messages = <ModelAiMessage>[msg];
    final List<String> stops = <String>['END'];
    final Set<EnumAiCapability> capabilities = <EnumAiCapability>{
      EnumAiCapability.textGeneration,
    };
    final ModelAiRequest immutable = request.copyWith(messages: messages);
    final ModelAiGenerationOptions immutableOptions = options.copyWith(
      stopSequences: stops,
    );
    final ModelAiDescriptor immutableDescriptor = model.copyWith(
      capabilities: capabilities,
    );
    messages.clear();
    stops.clear();
    capabilities.clear();
    expect(immutable.messages, <ModelAiMessage>[msg]);
    expect(immutableOptions.stopSequences, <String>['END']);
    expect(immutableDescriptor.capabilities, <EnumAiCapability>{
      EnumAiCapability.textGeneration,
    });
    expect(() => immutable.messages.add(msg), throwsUnsupportedError);
    expect(
      () => immutableOptions.stopSequences.add('X'),
      throwsUnsupportedError,
    );
    expect(
      () => immutableDescriptor.capabilities.clear(),
      throwsUnsupportedError,
    );
    final Map<String, dynamic> json = immutable.toJson();
    final List<dynamic> jsonMessages = json['messages'] as List<dynamic>;
    (jsonMessages.first as Map<String, dynamic>)['content'] = 'changed';
    jsonMessages.clear();
    (json['options'] as Map<String, dynamic>)['temperature'] = 5;
    (immutableOptions.toJson()['stopSequences'] as List<String>).clear();
    (immutableDescriptor.toJson()['capabilities'] as List<String>).clear();
    expect(immutable, request);
    expect(immutableOptions, options);
    expect(immutableDescriptor, model);
    final Map<String, dynamic> incoming = request.toJson();
    final ModelAiRequest decoded = ModelAiRequest.fromJson(incoming);
    (incoming['messages'] as List<dynamic>).clear();
    expect(decoded, request);
  });

  test('ordered context and stop sequences retain order', () {
    final ModelAiRequest a = request.copyWith(
      messages: <ModelAiMessage>[msg, message('Second')],
    );
    final ModelAiRequest b = request.copyWith(
      messages: <ModelAiMessage>[message('Second'), msg],
    );
    expect(a, isNot(b));
    expect(
      options.copyWith(stopSequences: <String>['A', 'B']),
      isNot(options.copyWith(stopSequences: <String>['B', 'A'])),
    );
    expect(
      ModelAiDescriptor.fromJson(
        model.toJson()
          ..['capabilities'] = <String>['textGeneration', 'textGeneration'],
      ),
      model,
    );
    expect(
      jsonEncode(model.toJson()),
      jsonEncode(
        model
            .copyWith(
              capabilities: <EnumAiCapability>{EnumAiCapability.textGeneration},
            )
            .toJson(),
      ),
    );
  });

  test('source integrity and locations are validated independently', () {
    expect(
      ModelAiSource.remoteDownload(
        url: 'https://example.com/m',
        expectedSha256: sha.toUpperCase(),
      ).expectedSha256,
      sha,
    );
    for (final ModelAiSource item in sources) {
      expect(ModelAiSource.fromJson(item.toJson()), item);
    }
    final List<ModelAiSource Function()> invalid = <ModelAiSource Function()>[
      () => ModelAiSource(type: EnumAiSourceType.localFile),
      () => ModelAiSource.localFile(path: ' '),
      () => ModelAiSource.bundledAsset(assetPath: ''),
      () => ModelAiSource(
        type: EnumAiSourceType.localFile,
        path: 'p',
        url: 'https://example.com',
      ),
      () => ModelAiSource(
        type: EnumAiSourceType.bundledAsset,
        assetPath: 'a',
        path: 'p',
      ),
      () => ModelAiSource(
        type: EnumAiSourceType.remoteDownload,
        url: 'https://example.com',
      ),
      () => ModelAiSource.remoteDownload(
        url: 'https://example.com',
        expectedSha256: 'bad',
      ),
      () => ModelAiSource.localFile(
        path: 'p',
        expectedSha256: List<String>.filled(64, 'z').join(),
      ),
    ];
    for (final ModelAiSource Function() build in invalid) {
      expect(build, throwsArgumentError);
    }
    for (final String url in <String>[
      'http://example.com/m',
      '/m',
      'https:///m',
      'https://user:pass@example.com/m',
      'https://example.com/m#part',
      'https://[',
    ]) {
      expect(
        () => ModelAiSource.remoteDownload(url: url, expectedSha256: sha),
        throwsArgumentError,
      );
    }
  });

  test(
    'every public enum value round trips by name; unknown values fail closed',
    () {
      for (final EnumAiMessageRole role in EnumAiMessageRole.values) {
        final ModelAiMessage v = msg.copyWith(role: role);
        expect(ModelAiMessage.fromJson(v.toJson()), v);
      }
      for (final EnumAiFinishReason reason in EnumAiFinishReason.values) {
        final ModelAiResponse v = response.copyWith(finishReason: reason);
        expect(ModelAiResponse.fromJson(v.toJson()), v);
      }
      for (final EnumAiFailureCode code in EnumAiFailureCode.values) {
        final ModelAiFailure v = error.copyWith(code: code);
        expect(ModelAiFailure.fromJson(v.toJson()), v);
      }
      for (final EnumAiModelStatus status in EnumAiModelStatus.values) {
        final ModelAiState v = ModelAiState(
          modelId: 'demo',
          status: status,
          failure: status == EnumAiModelStatus.failed ? error : null,
        );
        expect(ModelAiState.fromJson(v.toJson()), v);
      }
      for (final Object? unknown in <Object?>['futureValue', 0, null]) {
        expect(
          () => ModelAiMessage.fromJson(msg.toJson()..['role'] = unknown),
          throwsFormatException,
        );
        expect(
          () => ModelAiSource.fromJson(source().toJson()..['type'] = unknown),
          throwsFormatException,
        );
        expect(
          () => ModelAiState.fromJson(state.toJson()..['status'] = unknown),
          throwsFormatException,
        );
        expect(
          () => ModelAiResponse.fromJson(
            response.toJson()..['finishReason'] = unknown,
          ),
          throwsFormatException,
        );
        expect(
          () => ModelAiFailure.fromJson(error.toJson()..['code'] = unknown),
          throwsFormatException,
        );
        expect(
          () => ModelAiDescriptor.fromJson(
            model.toJson()..['capabilities'] = <Object?>[unknown],
          ),
          throwsFormatException,
        );
      }
    },
  );

  test('v0 finish reasons reject cancellation payloads instead of implying control', () {
    expect(
      EnumAiFinishReason.values
          .map((EnumAiFinishReason reason) => reason.name)
          .toList(),
      <String>['completed', 'outputLimit'],
    );
    expect(
      () => ModelAiResponse.fromJson(
        response.toJson()..['finishReason'] = 'cancelled',
      ),
      throwsFormatException,
    );
  });

  test('URL validation checks userInfo and fragments, not query content', () {
    final ModelAiSource query = ModelAiSource.remoteDownload(
      url: 'https://example.com/model?token=fixture',
      expectedSha256: sha,
    );
    expect(ModelAiSource.fromJson(query.toJson()), query);
    for (final String url in <String>[
      'https://user@example.com/model',
      'https://example.com/model#',
    ]) {
      expect(
        () => ModelAiSource.remoteDownload(url: url, expectedSha256: sha),
        throwsArgumentError,
      );
      expect(
        () => ModelAiSource.fromJson(query.toJson()..['url'] = url),
        throwsFormatException,
      );
    }
  });

  test('constructors and copyWith enforce bounds without assertions', () {
    for (final int bad in <int>[-1, -100]) {
      expect(() => usage.copyWith(inputTokens: bad), throwsArgumentError);
      expect(() => usage.copyWith(outputTokens: bad), throwsArgumentError);
      expect(() => usage.copyWith(totalTokens: bad), throwsArgumentError);
      expect(
        () => requirements.copyWith(storageBytes: bad),
        throwsArgumentError,
      );
      expect(
        () => requirements.copyWith(minimumMemoryBytes: bad),
        throwsArgumentError,
      );
    }
    expect(() => options.copyWith(maxOutputTokens: 0), throwsArgumentError);
    for (final double bad in <double>[
      -0.1,
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      expect(() => options.copyWith(temperature: bad), throwsArgumentError);
      expect(() => state.copyWith(progress: bad), throwsArgumentError);
    }
    expect(() => state.copyWith(progress: 1.01), throwsArgumentError);
    expect(state.copyWith(progress: 0.0).progress, 0.0);
    expect(state.copyWith(progress: 1.0).progress, 1.0);
    expect(options.copyWith(temperature: 0.0).temperature, 0.0);
    expect(
      () => state.copyWith(status: EnumAiModelStatus.ready),
      throwsArgumentError,
    );
    expect(() => state.copyWith(modelId: ' '), throwsArgumentError);
    expect(() => request.copyWith(requestId: ''), throwsArgumentError);
    expect(() => request.copyWith(modelId: ''), throwsArgumentError);
    expect(
      () => request.copyWith(messages: <ModelAiMessage>[]),
      throwsArgumentError,
    );
    expect(() => msg.copyWith(content: ''), throwsArgumentError);
    expect(message(' ').content, ' ');
    expect(
      () => options.copyWith(stopSequences: <String>['']),
      throwsArgumentError,
    );
    expect(() => model.copyWith(id: ''), throwsArgumentError);
    expect(() => model.copyWith(displayName: ''), throwsArgumentError);
    expect(() => model.copyWith(version: ''), throwsArgumentError);
    expect(
      () => model.copyWith(capabilities: <EnumAiCapability>{}),
      throwsArgumentError,
    );
    expect(() => response.copyWith(requestId: ''), throwsArgumentError);
    expect(() => response.copyWith(modelId: ''), throwsArgumentError);
    expect(() => error.copyWith(message: ''), throwsArgumentError);
  });

  test('malformed JSON consistently reports FormatException', () {
    final List<
      ({
        Map<String, dynamic> json,
        Object Function(Map<String, dynamic>) decode,
        List<String> requiredKeys,
      })
    >
    cases =
        <
          ({
            Map<String, dynamic> json,
            Object Function(Map<String, dynamic>) decode,
            List<String> requiredKeys,
          })
        >[
          (
            json: msg.toJson(),
            decode: ModelAiMessage.fromJson,
            requiredKeys: <String>['role', 'content'],
          ),
          (
            json: request.toJson(),
            decode: ModelAiRequest.fromJson,
            requiredKeys: <String>[
              'requestId',
              'modelId',
              'messages',
              'options',
            ],
          ),
          (
            json: response.toJson(),
            decode: ModelAiResponse.fromJson,
            requiredKeys: <String>[
              'requestId',
              'modelId',
              'text',
              'finishReason',
            ],
          ),
          (
            json: model.toJson(),
            decode: ModelAiDescriptor.fromJson,
            requiredKeys: <String>[
              'id',
              'displayName',
              'version',
              'capabilities',
              'requirements',
              'source',
            ],
          ),
          (
            json: state.toJson(),
            decode: ModelAiState.fromJson,
            requiredKeys: <String>['modelId', 'status', 'failure'],
          ),
          (
            json: error.toJson(),
            decode: ModelAiFailure.fromJson,
            requiredKeys: <String>['code', 'message', 'retryable'],
          ),
          (
            json: sources[3].toJson(),
            decode: ModelAiSource.fromJson,
            requiredKeys: <String>['type', 'url', 'expectedSha256'],
          ),
        ];
    for (final ({
          Map<String, dynamic> json,
          Object Function(Map<String, dynamic>) decode,
          List<String> requiredKeys,
        })
        item
        in cases) {
      for (final String key in item.requiredKeys) {
        expect(
          () => item.decode(Map<String, dynamic>.of(item.json)..remove(key)),
          throwsFormatException,
          reason: 'Missing $key',
        );
        expect(
          () => item.decode(Map<String, dynamic>.of(item.json)..[key] = 42),
          throwsFormatException,
          reason: 'Malformed $key',
        );
      }
    }
    expect(
      () => ModelAiMessage.fromJson(msg.toJson()..['content'] = ''),
      throwsFormatException,
    );
    expect(
      () => ModelAiRequest.fromJson(
        request.toJson()..['messages'] = <Object?>[null],
      ),
      throwsFormatException,
    );
    expect(
      () =>
          ModelAiRequest.fromJson(request.toJson()..['messages'] = <Object?>[]),
      throwsFormatException,
    );
    expect(
      () => ModelAiSource.fromJson(source().toJson()..['path'] = ''),
      throwsFormatException,
    );
    expect(
      () => ModelAiSource.fromJson(source().toJson()..['expectedSha256'] = 42),
      throwsFormatException,
    );
    expect(
      () => ModelAiDescriptor.fromJson(
        model.toJson()..['capabilities'] = <Object?>[],
      ),
      throwsFormatException,
    );
    expect(
      () => ModelAiState.fromJson(state.toJson()..['progress'] = '0.5'),
      throwsFormatException,
    );
    expect(
      () => ModelAiState.fromJson(state.toJson()..['progress'] = 2),
      throwsFormatException,
    );
    expect(
      () => ModelAiResponse.fromJson(response.toJson()..['usage'] = false),
      throwsFormatException,
    );
    expect(
      () => ModelAiGenerationOptions.fromJson(
        options.toJson()..['stopSequences'] = null,
      ),
      throwsFormatException,
    );
    expect(
      () => ModelAiGenerationOptions.fromJson(
        options.toJson()..['stopSequences'] = <int>[1],
      ),
      throwsFormatException,
    );
    expect(
      () => ModelAiGenerationOptions.fromJson(
        options.toJson()..['temperature'] = true,
      ),
      throwsFormatException,
    );
    expect(
      () => ModelAiGenerationOptions.fromJson(
        options.toJson()..['maxOutputTokens'] = 0,
      ),
      throwsFormatException,
    );
    expect(
      ModelAiGenerationOptions.fromJson(options.toJson()..['temperature'] = 1)
          .temperature,
      1.0,
    );
    expect(
      () => ModelAiUsage.fromJson(<String, dynamic>{'inputTokens': 1.5}),
      throwsFormatException,
    );
    expect(
      () => ModelAiUsage.fromJson(<String, dynamic>{'outputTokens': -1}),
      throwsFormatException,
    );
    expect(
      () =>
          ModelAiRequirements.fromJson(<String, dynamic>{'storageBytes': '10'}),
      throwsFormatException,
    );
    expect(
      () => ModelAiRequirements.fromJson(<String, dynamic>{
        'minimumMemoryBytes': -1,
      }),
      throwsFormatException,
    );
  });
}
