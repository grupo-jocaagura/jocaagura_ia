import 'package:jocaagura_ai/jocaagura_ai.dart';
import 'package:test/test.dart';

void main() {
  final Map<EnumAiModelStatus, Set<EnumAiModelStatus>> edges =
      <EnumAiModelStatus, Set<EnumAiModelStatus>>{
        EnumAiModelStatus.notInstalled: <EnumAiModelStatus>{
          EnumAiModelStatus.installing,
        },
        EnumAiModelStatus.installing: <EnumAiModelStatus>{
          EnumAiModelStatus.verifying,
          EnumAiModelStatus.failed,
        },
        EnumAiModelStatus.verifying: <EnumAiModelStatus>{
          EnumAiModelStatus.installed,
          EnumAiModelStatus.failed,
        },
        EnumAiModelStatus.installed: <EnumAiModelStatus>{
          EnumAiModelStatus.loading,
          EnumAiModelStatus.removing,
        },
        EnumAiModelStatus.loading: <EnumAiModelStatus>{
          EnumAiModelStatus.ready,
          EnumAiModelStatus.failed,
        },
        EnumAiModelStatus.ready: <EnumAiModelStatus>{
          EnumAiModelStatus.unloading,
        },
        EnumAiModelStatus.unloading: <EnumAiModelStatus>{
          EnumAiModelStatus.installed,
          EnumAiModelStatus.failed,
        },
        EnumAiModelStatus.removing: <EnumAiModelStatus>{
          EnumAiModelStatus.notInstalled,
          EnumAiModelStatus.failed,
        },
        EnumAiModelStatus.failed: <EnumAiModelStatus>{
          EnumAiModelStatus.installed,
          EnumAiModelStatus.notInstalled,
        },
      };
  test(
    'failed recovery establishes a resource state before another operation',
    () {
      final ModelAiState failed = ModelAiState(
        modelId: 'demo',
        status: EnumAiModelStatus.failed,
        failure: ModelAiFailure(
          code: EnumAiFailureCode.modelLoadFailure,
          message: 'Load failed',
        ),
      );
      expect(
        () => failed.copyWith(status: EnumAiModelStatus.installed),
        throwsArgumentError,
      );
      for (final EnumAiModelStatus recovered in <EnumAiModelStatus>[
        EnumAiModelStatus.installed,
        EnumAiModelStatus.notInstalled,
      ]) {
        final ModelAiState verified = failed.copyWith(
          status: recovered,
          failure: null,
        );
        expect(failed.status.canTransitionTo(verified.status), isTrue);
        expect(verified.failure, isNull);
      }
      expect(
        EnumAiModelStatus.installed.canTransitionTo(EnumAiModelStatus.loading),
        isTrue,
      );
      expect(
        EnumAiModelStatus.installed.canTransitionTo(EnumAiModelStatus.removing),
        isTrue,
      );
      expect(
        EnumAiModelStatus.notInstalled.canTransitionTo(
          EnumAiModelStatus.installing,
        ),
        isTrue,
      );
    },
  );
  for (final EnumAiModelStatus from in EnumAiModelStatus.values) {
    for (final EnumAiModelStatus to in EnumAiModelStatus.values) {
      test('$from -> $to respects the documented lifecycle', () {
        expect(
          from.canTransitionTo(to),
          from == to || edges[from]!.contains(to),
        );
      });
    }
  }
}
