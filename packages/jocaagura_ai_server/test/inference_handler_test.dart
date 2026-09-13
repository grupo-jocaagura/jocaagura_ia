import 'dart:convert';

import 'package:jocaagura_ai/jocaagura_ai.dart';
import 'package:jocaagura_ai_server/src/api/inference_handler.dart';
import 'package:jocaagura_ai_server/src/application/poc_application.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

final class TestGateway implements AiGateway {
  TestGateway(this.action);
  final Future<AiResult<ModelAiResponse>> Function(ModelAiRequest) action;
  @override
  Future<AiResult<ModelAiResponse>> infer(ModelAiRequest request) =>
      action(request);
}

void main() {
  late Handler handler;
  late List<ModelAiRequest> calls;
  setUp(() {
    calls = <ModelAiRequest>[];
    handler = inferenceHandler(
      TestGateway((ModelAiRequest request) async {
        calls.add(request);
        return AiSuccess<ModelAiResponse>(
          ModelAiResponse(
            requestId: request.requestId,
            modelId: request.modelId,
            text: 'OK',
            finishReason: EnumAiFinishReason.completed,
          ),
        );
      }),
    );
  });

  Request request(
    Object body, {
    String method = 'POST',
    String path = 'v1/inference',
  }) => Request(method, Uri.parse('http://localhost/$path'), body: body);

  test('decodes actual JSON into existing request and serializes the domain response', () async {
    final ModelAiRequest value = smokeRequest();
    final Response response = await handler(
      request(jsonEncode(value.toJson())),
    );
    expect(calls, <ModelAiRequest>[value]);
    expect(response.statusCode, 200);
    expect(response.headers['content-type'], contains('application/json'));
    final Map<String, dynamic> json =
        jsonDecode(await response.readAsString()) as Map<String, dynamic>;
    expect(json.containsKey('value'), isFalse);
    expect(ModelAiResponse.fromJson(json).requestId, value.requestId);
  });

  test('malformed or invalid domain JSON never reaches gateway', () async {
    for (final Object body in <Object>[
      '{',
      '[]',
      'null',
      '{}',
      '{"requestId":4}',
      <int>[255],
    ]) {
      final Response response = await handler(request(body));
      expect(response.statusCode, 400);
      final ModelAiFailure failure = ModelAiFailure.fromJson(
        jsonDecode(await response.readAsString()) as Map<String, dynamic>,
      );
      expect(failure.code, EnumAiFailureCode.invalidRequest);
    }
    expect(calls, isEmpty);
  });

  test('legacy textual JSON remains readable and canonical parts preserve the request', () async {
    final ModelAiRequest original = smokeRequest();
    final Map<String, dynamic> legacy = original.toJson()
      ..['messages'] = <Map<String, dynamic>>[
        <String, dynamic>{'role': 'user', 'content': 'Respond only with OK'},
      ];
    expect((await handler(request(jsonEncode(legacy)))).statusCode, 200);
    expect(
      (await handler(request(jsonEncode(original.toJson())))).statusCode,
      200,
    );
    expect(calls, <ModelAiRequest>[original, original]);
    final Map<String, dynamic> invalid = original.toJson()
      ..['messages'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'role': 'user',
          'parts': <Map<String, dynamic>>[
            <String, dynamic>{
              'type': 'image',
              'mimeType': 'image/png',
              'source': <String, dynamic>{
                'type': 'inlineBytes',
                'bytesBase64': 'invalid!',
              },
            },
          ],
        },
      ];
    expect((await handler(request(jsonEncode(invalid)))).statusCode, 400);
    expect(calls, hasLength(2));
  });

  test('bounds streamed body before decoding', () async {
    final Response response = await handler(
      request(
        Stream<List<int>>.fromIterable(<List<int>>[
          List<int>.filled(32768, 32),
          <int>[32],
        ]),
      ),
    );
    expect(response.statusCode, 413);
    expect(calls, isEmpty);
  });

  test('unknown path and method are distinct transport failures', () async {
    expect((await handler(request('', path: 'missing'))).statusCode, 404);
    final Response response = await handler(request('', method: 'GET'));
    expect(response.statusCode, 405);
    expect(response.headers['allow'], 'POST');
    expect(calls, isEmpty);
  });

  test(
    'every domain error has the documented HTTP mapping and original JSON',
    () async {
      const Map<EnumAiFailureCode, int> statuses = <EnumAiFailureCode, int>{
        EnumAiFailureCode.invalidRequest: 400,
        EnumAiFailureCode.unsupportedCapability: 422,
        EnumAiFailureCode.modelUnavailable: 503,
        EnumAiFailureCode.insufficientResources: 503,
        EnumAiFailureCode.integrityFailure: 500,
        EnumAiFailureCode.modelLoadFailure: 500,
        EnumAiFailureCode.inferenceFailure: 500,
      };
      for (final MapEntry<EnumAiFailureCode, int> entry in statuses.entries) {
        final ModelAiFailure failure = ModelAiFailure(
          code: entry.key,
          message: 'expected',
          retryable: true,
        );
        handler = inferenceHandler(
          TestGateway((_) async => AiFailureResult<ModelAiResponse>(failure)),
        );
        final Response response = await handler(
          request(jsonEncode(smokeRequest().toJson())),
        );
        expect(response.statusCode, entry.value);
        expect(jsonDecode(await response.readAsString()), failure.toJson());
      }
    },
  );

  test('unexpected errors stay on the server side', () async {
    handler = inferenceHandler(
      TestGateway((_) async => throw StateError('private runtime path')),
    );
    final Response response = await handler(
      request(jsonEncode(smokeRequest().toJson())),
    );
    expect(response.statusCode, 500);
    final String body = await response.readAsString();
    expect(body, isNot(contains('private runtime path')));
    expect(
      ModelAiFailure.fromJson(jsonDecode(body) as Map<String, dynamic>).code,
      EnumAiFailureCode.inferenceFailure,
    );
  });
}
