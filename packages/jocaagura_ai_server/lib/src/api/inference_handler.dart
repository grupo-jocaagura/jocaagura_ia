import 'dart:convert';

import 'package:jocaagura_ai/jocaagura_ai.dart';
import 'package:shelf/shelf.dart';

/// HTTP is a transport for the existing domain, not an inference dependency.
Handler inferenceHandler(AiGateway gateway) => (Request request) async {
  if (request.url.path != 'v1/inference') {
    return Response.notFound('Not found');
  }
  if (request.method != 'POST') {
    return Response(405, headers: <String, String>{'allow': 'POST'});
  }
  ModelAiRequest modelRequest;
  try {
    final List<int> bytes = <int>[];
    await for (final List<int> chunk in request.read()) {
      if (bytes.length + chunk.length > 32768) {
        return _jsonFailure(413, 'Request body exceeds 32768 bytes.');
      }
      bytes.addAll(chunk);
    }
    final Object? body = jsonDecode(utf8.decode(bytes));
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object.');
    }
    modelRequest = ModelAiRequest.fromJson(body);
  } on FormatException {
    return _jsonFailure(400, 'Invalid inference request JSON.');
  }
  try {
    return switch (await gateway.infer(modelRequest)) {
      AiSuccess<ModelAiResponse>(value: final ModelAiResponse value) => _json(
        200,
        value.toJson(),
      ),
      AiFailureResult<ModelAiResponse>(failure: final ModelAiFailure failure) =>
        _json(failureStatus(failure.code), failure.toJson()),
    };
  } catch (_) {
    // HTTP isolates unexpected application errors; the adapter itself does not
    // swallow programming errors. Native details/paths never go into responses.
    return _json(
      500,
      ModelAiFailure(
        code: EnumAiFailureCode.inferenceFailure,
        message: 'Internal server error.',
      ).toJson(),
    );
  }
};

int failureStatus(EnumAiFailureCode code) => switch (code) {
  EnumAiFailureCode.invalidRequest => 400,
  EnumAiFailureCode.unsupportedCapability => 422,
  EnumAiFailureCode.modelUnavailable ||
  EnumAiFailureCode.insufficientResources => 503,
  EnumAiFailureCode.integrityFailure ||
  EnumAiFailureCode.modelLoadFailure ||
  EnumAiFailureCode.inferenceFailure => 500,
};

Response _jsonFailure(int status, String message) => _json(
  status,
  ModelAiFailure(
    code: EnumAiFailureCode.invalidRequest,
    message: message,
  ).toJson(),
);

Response _json(int status, Map<String, dynamic> body) => Response(
  status,
  body: jsonEncode(body),
  headers: <String, String>{'content-type': 'application/json; charset=utf-8'},
);
