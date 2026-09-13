import 'dart:convert';

import 'package:jocaagura_ai/jocaagura_ai.dart';
import 'package:test/test.dart';

final String sha = List<String>.filled(64, 'a').join();
ModelAiMessage message([String content = 'Respond only with OK']) =>
    ModelAiMessage.text(role: EnumAiMessageRole.user, text: content);
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
