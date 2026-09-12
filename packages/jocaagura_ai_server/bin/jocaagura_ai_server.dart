import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:jocaagura_ai_server/src/application/poc_application.dart';
import 'package:jocaagura_ia/jocaagura_ia.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main(List<String> args) async {
  final String? modelPath = Platform.environment['JOCAAGURA_MODEL_PATH'];
  if (modelPath == null ||
      args.length != 1 ||
      !<String>['smoke', 'serve'].contains(args.single)) {
    stderr.writeln('Set JOCAAGURA_MODEL_PATH; use smoke or serve.');
    exitCode = 64;
    return;
  }
  final PocApplication app = PocApplication.local(modelPath);
  if (args.single == 'smoke') {
    final Stopwatch elapsed = Stopwatch()..start();
    try {
      final AiResult<ModelAiResponse> result = await app.smoke();
      stdout.writeln(
        jsonEncode(<String, Object?>{
          'passed': smokePassed(result),
          'elapsedMs': elapsed.elapsedMilliseconds,
          'result': switch (result) {
            AiSuccess<ModelAiResponse>(value: final ModelAiResponse value) =>
              value.toJson(),
            AiFailureResult<ModelAiResponse>(
              failure: final ModelAiFailure failure,
            ) =>
              failure.toJson(),
          },
        }),
      );
      exitCode = smokePassed(result) ? 0 : 1;
    } finally {
      await app.close();
    }
    return;
  }
  final HttpServer server = await shelf_io.serve(
    app.handler,
    InternetAddress.loopbackIPv4,
    8080,
  );
  stdout.writeln('POST http://127.0.0.1:8080/v1/inference');
  // Disconnecting an HTTP client or this signal observer never cancels inference.
  await ProcessSignal.sigint.watch().first;
  await server.close();
  await app.close();
}
