import 'dart:async';

import 'package:jocaagura_ai/jocaagura_ai.dart';
import 'package:test/test.dart';

/// Test-only simulation: does not acquire files or execute inference.
class MemoryManager implements AiModelManager {
  final Map<String, ModelAiDescriptor> models = <String, ModelAiDescriptor>{};
  final Map<String, ModelAiState> states = <String, ModelAiState>{};
  final Map<String, StreamController<ModelAiState>> controllers =
      <String, StreamController<ModelAiState>>{};

  ModelAiState snapshot(String id) =>
      states[id] ??
      ModelAiState(modelId: id, status: EnumAiModelStatus.notInstalled);

  ModelAiState emit(String id, EnumAiModelStatus next) {
    final ModelAiState previous = snapshot(id);
    if (!previous.status.canTransitionTo(next)) {
      throw StateError('Invalid fake lifecycle transition');
    }
    final ModelAiState state = ModelAiState(modelId: id, status: next);
    states[id] = state;
    controllers[id]?.add(state);
    return state;
  }

  AiFailureResult<ModelAiState> invalid() => AiFailureResult<ModelAiState>(
    ModelAiFailure(
      code: EnumAiFailureCode.invalidRequest,
      message: 'Operation is incompatible with the current model state',
    ),
  );

  @override
  Future<AiResult<List<ModelAiDescriptor>>> discover() async =>
      AiSuccess<List<ModelAiDescriptor>>(
        List<ModelAiDescriptor>.unmodifiable(models.values),
      );

  @override
  Future<AiResult<ModelAiState>> install(ModelAiDescriptor model) async {
    final ModelAiDescriptor? existing = models[model.id];
    if (existing != null && existing != model) {
      return invalid();
    }
    final ModelAiState current = snapshot(model.id);
    if (current.status == EnumAiModelStatus.installed) {
      return AiSuccess<ModelAiState>(current);
    }
    if (current.status != EnumAiModelStatus.notInstalled) {
      return invalid();
    }
    models[model.id] = model;
    emit(model.id, EnumAiModelStatus.installing);
    emit(model.id, EnumAiModelStatus.verifying);
    return AiSuccess<ModelAiState>(emit(model.id, EnumAiModelStatus.installed));
  }

  @override
  Future<AiResult<ModelAiState>> load(String modelId) async {
    final ModelAiState current = snapshot(modelId);
    if (current.status == EnumAiModelStatus.ready) {
      return AiSuccess<ModelAiState>(current);
    }
    if (current.status == EnumAiModelStatus.notInstalled) {
      return AiFailureResult<ModelAiState>(
        ModelAiFailure(
          code: EnumAiFailureCode.modelUnavailable,
          message: 'Install resources first',
        ),
      );
    }
    if (current.status != EnumAiModelStatus.installed) {
      return invalid();
    }
    emit(modelId, EnumAiModelStatus.loading);
    return AiSuccess<ModelAiState>(emit(modelId, EnumAiModelStatus.ready));
  }

  @override
  Future<AiResult<ModelAiState>> unload(String modelId) async {
    final ModelAiState current = snapshot(modelId);
    if (current.status == EnumAiModelStatus.installed) {
      return AiSuccess<ModelAiState>(current);
    }
    if (current.status != EnumAiModelStatus.ready) {
      return invalid();
    }
    emit(modelId, EnumAiModelStatus.unloading);
    return AiSuccess<ModelAiState>(emit(modelId, EnumAiModelStatus.installed));
  }

  @override
  Future<AiResult<ModelAiState>> remove(String modelId) async {
    final ModelAiState current = snapshot(modelId);
    if (current.status == EnumAiModelStatus.notInstalled) {
      return AiSuccess<ModelAiState>(current);
    }
    if (current.status != EnumAiModelStatus.installed) {
      return invalid();
    }
    emit(modelId, EnumAiModelStatus.removing);
    models.remove(modelId);
    return AiSuccess<ModelAiState>(
      emit(modelId, EnumAiModelStatus.notInstalled),
    );
  }

  @override
  Stream<ModelAiState> watch(String modelId) {
    final ModelAiState initial = snapshot(modelId);
    final StreamController<ModelAiState> changes = controllers.putIfAbsent(
      modelId,
      () => StreamController<ModelAiState>.broadcast(),
    );
    return Stream<ModelAiState>.multi((
      MultiStreamController<ModelAiState> sink,
    ) {
      final StreamSubscription<ModelAiState> subscription = changes.stream
          .listen(sink.addSync, onDone: sink.closeSync);
      sink.onCancel = subscription.cancel;
      sink.addSync(states[modelId] ?? initial);
    });
  }

  Future<void> dispose() async {
    for (final StreamController<ModelAiState> controller
        in controllers.values) {
      await controller.close();
    }
  }
}

class FixtureGateway implements AiGateway {
  FixtureGateway(this.manager);
  final MemoryManager manager;

  @override
  Future<AiResult<ModelAiResponse>> infer(ModelAiRequest request) async {
    if (manager.snapshot(request.modelId).status != EnumAiModelStatus.ready) {
      return AiFailureResult<ModelAiResponse>(
        ModelAiFailure(
          code: EnumAiFailureCode.modelUnavailable,
          message: 'Model is not loaded',
        ),
      );
    }
    return AiSuccess<ModelAiResponse>(
      ModelAiResponse(
        requestId: request.requestId,
        modelId: request.modelId,
        text: 'OK',
        finishReason: EnumAiFinishReason.completed,
      ),
    );
  }
}

void main() {
  test('interfaces compose acquisition, loading, inference and cleanup without a runtime', () async {
    final MemoryManager manager = MemoryManager();
    addTearDown(manager.dispose);
    final AiModelManager contract = manager;
    final AiGateway gateway = FixtureGateway(manager);
    final ModelAiDescriptor model = ModelAiDescriptor(
      id: 'demo',
      displayName: 'Demo',
      version: 'a',
      capabilities: <EnumAiCapability>{EnumAiCapability.textGeneration},
      requirements: ModelAiRequirements(),
      source: ModelAiSource.localFile(path: 'test-fixture.bin'),
    );
    final ModelAiRequest request = ModelAiRequest(
      requestId: 'r',
      modelId: model.id,
      messages: <ModelAiMessage>[
        ModelAiMessage.text(role: EnumAiMessageRole.user, text: 'OK'),
      ],
    );
    expect(
      await gateway.infer(request),
      isA<AiFailureResult<ModelAiResponse>>(),
    );
    final Future<List<ModelAiState>> watched = contract
        .watch(model.id)
        .take(10)
        .toList();
    expect(
      (await contract.install(model) as AiSuccess<ModelAiState>).value.status,
      EnumAiModelStatus.installed,
    );
    expect(
      await gateway.infer(request),
      isA<AiFailureResult<ModelAiResponse>>(),
    );
    final AiResult<List<ModelAiDescriptor>> discovered = await contract
        .discover();
    final List<ModelAiDescriptor> models =
        (discovered as AiSuccess<List<ModelAiDescriptor>>).value;
    expect(models, <ModelAiDescriptor>[model]);
    expect(() => models.clear(), throwsUnsupportedError);
    await contract.load(model.id);
    final AiResult<ModelAiResponse> result = await gateway.infer(request);
    final String text = switch (result) {
      AiSuccess<ModelAiResponse>(:final ModelAiResponse value) => value.text,
      AiFailureResult<ModelAiResponse>(:final ModelAiFailure failure) =>
        failure.message,
    };
    expect(text, 'OK');
    final ModelAiResponse response =
        (result as AiSuccess<ModelAiResponse>).value;
    expect(response.requestId, request.requestId);
    expect(response.modelId, request.modelId);
    await contract.unload(model.id);
    await contract.remove(model.id);
    expect(
      (await watched).map((ModelAiState state) => state.status).toList(),
      <EnumAiModelStatus>[
        EnumAiModelStatus.notInstalled,
        EnumAiModelStatus.installing,
        EnumAiModelStatus.verifying,
        EnumAiModelStatus.installed,
        EnumAiModelStatus.loading,
        EnumAiModelStatus.ready,
        EnumAiModelStatus.unloading,
        EnumAiModelStatus.installed,
        EnumAiModelStatus.removing,
        EnumAiModelStatus.notInstalled,
      ],
    );
    expect(manager.controllers[model.id]!.hasListener, isFalse);
  });

  test(
    'operational failures are exhaustively represented as domain values',
    () async {
      final MemoryManager manager = MemoryManager();
      addTearDown(manager.dispose);
      final AiResult<ModelAiState> result = await manager.load('missing');
      final EnumAiFailureCode? code = switch (result) {
        AiSuccess<ModelAiState>() => null,
        AiFailureResult<ModelAiState>(:final ModelAiFailure failure) =>
          failure.code,
      };
      expect(code, EnumAiFailureCode.modelUnavailable);
      expect(() => manager.watch(' '), throwsArgumentError);
    },
  );
}
