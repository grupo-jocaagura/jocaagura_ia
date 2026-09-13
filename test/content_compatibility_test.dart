import 'dart:convert';

import 'package:jocaagura_ai/jocaagura_ai.dart';
import 'package:test/test.dart';

import 'fixtures/content_fixtures.dart';
import 'fixtures/domain_fixtures.dart' show descriptor;

// This fake validates declarations only and never resolves input resources.
class ContentFixtureGateway implements AiGateway {
  ContentFixtureGateway(
    this.model,
    this.backend, {
    this.runtimeRejects = false,
  });
  final ModelAiContentCapabilities? model;
  final ModelAiContentCapabilities? backend;
  final bool runtimeRejects;
  int executions = 0;

  @override
  Future<AiResult<ModelAiResponse>> infer(ModelAiRequest request) async {
    final ModelAiContentCompatibility result = assessAiContentCompatibility(
      request: request,
      modelCapabilities: model,
      backendCapabilities: backend,
    );
    if (result.status !=
        EnumAiContentCompatibilityStatus.meetsDeclaredConstraints) {
      return AiFailureResult<ModelAiResponse>(
        ModelAiFailure(
          code: EnumAiFailureCode.unsupportedCapability,
          message:
              result.status == EnumAiContentCompatibilityStatus.undetermined
              ? 'Support is not established by the selected declarations.'
              : 'Input is outside the selected declarations.',
        ),
      );
    }
    executions++;
    if (runtimeRejects) {
      return AiFailureResult<ModelAiResponse>(
        ModelAiFailure(
          code: EnumAiFailureCode.unsupportedCapability,
          message: 'Fixture runtime rejects this operation.',
        ),
      );
    }
    return AiSuccess<ModelAiResponse>(
      ModelAiResponse(
        requestId: request.requestId,
        modelId: request.modelId,
        text: '',
        finishReason: EnumAiFinishReason.completed,
      ),
    );
  }
}

void main() {
  final ModelAiContentCapabilities image = imageProfile();
  final ModelAiContentCapabilities text = textProfile();
  final ModelAiRequest mixed = contentRequest();
  final ModelAiRequest textRequest = contentRequest(<ModelAiContentPart>[
    ModelAiTextPart(text: 'x'),
  ]);
  ModelAiContentCompatibility assess(
    ModelAiRequest request,
    ModelAiContentCapabilities? model,
    ModelAiContentCapabilities? backend,
  ) => assessAiContentCompatibility(
    request: request,
    modelCapabilities: model,
    backendCapabilities: backend,
  );
  const EnumAiContentCompatibilityStatus matches =
      EnumAiContentCompatibilityStatus.meetsDeclaredConstraints;
  const EnumAiContentCompatibilityStatus denied =
      EnumAiContentCompatibilityStatus.unsupported;
  const EnumAiContentCompatibilityStatus unknown =
      EnumAiContentCompatibilityStatus.undetermined;

  test('null maxima do not make known support undetermined', () {
    expect(assess(textRequest, text, text).status, matches);
    expect(assess(mixed, image, image).status, matches);
    final ModelAiRequest local = contentRequest(<ModelAiContentPart>[
      imagePart(source: ModelAiLocalFileSource(path: 'not-on-disk.png')),
    ]);
    expect(assess(local, image, image).status, matches);
    final ModelAiContentCompatibility sizeUnknown = assess(
      local,
      image.copyWith(maxBytesPerImage: 3),
      image,
    );
    expect(sizeUnknown.status, unknown);
    expect(sizeUnknown.reasons, <String>[
      'model profile.maxBytesPerImage: messages[0].parts[0].source: byte size requires IO',
    ]);
    expect(
      assess(local, image, image.copyWith(maxBytesPerImage: 3)).status,
      unknown,
    );
  });

  final List<
    ({
      String name,
      ModelAiContentCapabilities? model,
      ModelAiContentCapabilities? backend,
      EnumAiContentCompatibilityStatus expected,
    })
  >
  cases =
      <
        ({
          String name,
          ModelAiContentCapabilities? model,
          ModelAiContentCapabilities? backend,
          EnumAiContentCompatibilityStatus expected,
        })
      >[
        (
          name: 'matching profiles',
          model: image,
          backend: image,
          expected: matches,
        ),
        (
          name: 'model image and backend text',
          model: image,
          backend: text,
          expected: denied,
        ),
        (
          name: 'model text and backend image',
          model: text,
          backend: image,
          expected: denied,
        ),
        (name: 'no profiles', model: null, backend: null, expected: unknown),
        (name: 'model unknown', model: null, backend: image, expected: unknown),
        (
          name: 'backend unknown',
          model: image,
          backend: null,
          expected: unknown,
        ),
        (
          name: 'denial overrides missing model',
          model: null,
          backend: text,
          expected: denied,
        ),
        (
          name: 'denial overrides missing backend',
          model: text,
          backend: null,
          expected: denied,
        ),
        (
          name: 'unknown role',
          model: image.copyWith(inputRoles: null),
          backend: image,
          expected: unknown,
        ),
        (
          name: 'unknown source',
          model: image,
          backend: image.copyWith(imageSourceTypes: null),
          expected: unknown,
        ),
        (
          name: 'unknown MIME',
          model: image.copyWith(imageMimeTypes: null),
          backend: image,
          expected: unknown,
        ),
        (
          name: 'empty roles',
          model: image.copyWith(inputRoles: <EnumAiMessageRole>{}),
          backend: image,
          expected: denied,
        ),
        (
          name: 'role mismatch',
          model: image,
          backend: image.copyWith(
            inputRoles: <EnumAiMessageRole>{EnumAiMessageRole.system},
          ),
          expected: denied,
        ),
        (
          name: 'source mismatch',
          model: image.copyWith(
            imageSourceTypes: <EnumAiContentSourceType>{
              EnumAiContentSourceType.localFile,
            },
          ),
          backend: image,
          expected: denied,
        ),
        (
          name: 'MIME mismatch',
          model: image,
          backend: image.copyWith(imageMimeTypes: <String>{'image/jpeg'}),
          expected: denied,
        ),
        (
          name: 'empty MIME',
          model: image.copyWith(imageMimeTypes: <String>{}),
          backend: image,
          expected: denied,
        ),
        (
          name: 'empty sources',
          model: image.copyWith(imageSourceTypes: <EnumAiContentSourceType>{}),
          backend: image,
          expected: denied,
        ),
        (
          name: 'no text output',
          model: image,
          backend: image.copyWith(outputModalities: <EnumAiOutputModality>{}),
          expected: denied,
        ),
        (
          name: 'no input',
          model: text.copyWith(inputModalities: <EnumAiInputModality>{}),
          backend: image,
          expected: denied,
        ),
        (
          name: 'text missing in mixed input',
          model: image.copyWith(
            inputModalities: <EnumAiInputModality>{EnumAiInputModality.image},
          ),
          backend: image,
          expected: denied,
        ),
        (
          name: 'bytes at boundary',
          model: image.copyWith(maxBytesPerImage: 3),
          backend: image.copyWith(maxBytesPerImage: 4),
          expected: matches,
        ),
        (
          name: 'smaller model bound wins',
          model: image.copyWith(maxBytesPerImage: 2),
          backend: image.copyWith(maxBytesPerImage: 4),
          expected: denied,
        ),
        (
          name: 'smaller backend bound wins',
          model: image.copyWith(maxBytesPerImage: 4),
          backend: image.copyWith(maxBytesPerImage: 2),
          expected: denied,
        ),
        (
          name: 'unknown allowlist does not erase denial',
          model: image.copyWith(imageMimeTypes: null),
          backend: image.copyWith(maxBytesPerImage: 2),
          expected: denied,
        ),
      ];
  for (final ({
        String name,
        ModelAiContentCapabilities? model,
        ModelAiContentCapabilities? backend,
        EnumAiContentCompatibilityStatus expected,
      })
      scenario
      in cases) {
    test('declaration assessment: ${scenario.name}', () {
      final ModelAiContentCompatibility result = assess(
        mixed,
        scenario.model,
        scenario.backend,
      );
      expect(result.status, scenario.expected);
      expect(result.reasons.isEmpty, scenario.expected == matches);
      expect(
        ModelAiContentCompatibility.fromJson(
          jsonDecode(jsonEncode(result.toJson())) as Map<String, dynamic>,
        ),
        result,
      );
    });
  }

  test('images are counted across messages and inline payload sizes are not Base64 sizes', () {
    final ModelAiRequest three = mixed.copyWith(
      messages: <ModelAiMessage>[
        mixed.messages.single,
        ModelAiMessage(
          role: EnumAiMessageRole.assistant,
          parts: <ModelAiContentPart>[imagePart(), imagePart()],
        ),
      ],
    );
    expect(
      assess(
        three,
        image.copyWith(
          maxMessagesPerRequest: 2,
          maxImagesPerRequest: 3,
          maxBytesPerImage: 3,
        ),
        image,
      ).status,
      matches,
    );
    expect(
      assess(three, image.copyWith(maxMessagesPerRequest: 1), image).status,
      denied,
    );
    expect(
      assess(three, image, image.copyWith(maxImagesPerRequest: 2)).status,
      denied,
    );
    expect(
      assess(
        three,
        image.copyWith(maxImagesPerRequest: 2),
        image.copyWith(maxImagesPerRequest: 3),
      ).status,
      denied,
    );
    expect(
      assess(three, image, image.copyWith(maxMessagesPerRequest: 1)).status,
      denied,
    );
    final ModelAiContentCapabilities unknownImages = image.copyWith(
      imageMimeTypes: null,
      imageSourceTypes: null,
      maxBytesPerImage: 1,
    );
    expect(assess(textRequest, unknownImages, text).status, matches);
  });

  test('unknown local size cannot override a known denial or use metadata as proof', () {
    final ModelAiRequest request = contentRequest(<ModelAiContentPart>[
      imagePart(source: ModelAiLocalFileSource(path: 'missing.png'))
          .copyWith(metadata: <String, String>{'bytes': '1'}),
    ]);
    expect(
      assess(request, image.copyWith(maxBytesPerImage: 1), image).status,
      unknown,
    );
    expect(
      assess(request, image.copyWith(maxBytesPerImage: 1), text).status,
      denied,
    );
  });

  test('diagnostics are deterministic in profile, field and part order', () {
    final ModelAiContentCapabilities restriction = image.copyWith(
      outputModalities: <EnumAiOutputModality>{},
      inputRoles: <EnumAiMessageRole>{},
      imageSourceTypes: <EnumAiContentSourceType>{},
      imageMimeTypes: <String>{},
      maxBytesPerImage: 1,
    );
    final ModelAiContentCompatibility result = assess(
      mixed,
      restriction,
      restriction,
    );
    const List<String> suffixes = <String>[
      '.outputModalities: not declared as supported',
      '.inputRoles: messages[0].role: not declared as supported',
      '.imageSourceTypes: messages[0].parts[1].source.type: not declared as supported',
      '.imageMimeTypes: messages[0].parts[1].mimeType: not declared as supported',
      '.maxBytesPerImage: messages[0].parts[1].source: declared maximum exceeded',
    ];
    expect(result.reasons, <String>[
      for (final String label in <String>['model profile', 'backend profile'])
        for (final String suffix in suffixes) '$label$suffix',
    ]);
    expect(
      result,
      assess(mixed, restriction.copyWith(), restriction.copyWith()),
    );
  });

  test(
    'capability collections, normalization, sorted sets and null clearing',
    () {
      final Set<EnumAiInputModality> inputs = EnumAiInputModality
          .values
          .reversed
          .toSet();
      final Set<EnumAiOutputModality> outputs = EnumAiOutputModality.values
          .toSet();
      final Set<EnumAiMessageRole> roles = EnumAiMessageRole.values.reversed
          .toSet();
      final Set<EnumAiContentSourceType> sources = EnumAiContentSourceType
          .values
          .reversed
          .toSet();
      final Set<String> mimes = <String>{'IMAGE/PNG', 'image/jpeg'};
      final ModelAiContentCapabilities value = ModelAiContentCapabilities(
        inputModalities: inputs,
        outputModalities: outputs,
        inputRoles: roles,
        imageSourceTypes: sources,
        imageMimeTypes: mimes,
      );
      inputs.clear();
      outputs.clear();
      roles.clear();
      sources.clear();
      mimes.clear();
      expect(value, image);
      expect(value.hashCode, image.hashCode);
      expect(jsonEncode(value.toJson()), jsonEncode(image.toJson()));
      for (final void Function() mutate in <void Function()>[
        () => value.inputModalities.clear(),
        () => value.outputModalities.clear(),
        () => value.inputRoles!.clear(),
        () => value.imageSourceTypes!.clear(),
        () => value.imageMimeTypes!.clear(),
      ]) {
        expect(mutate, throwsUnsupportedError);
      }
      final Map<String, dynamic> json = value.toJson();
      for (final String field in <String>[
        'inputModalities',
        'outputModalities',
        'inputRoles',
        'imageSourceTypes',
        'imageMimeTypes',
      ]) {
        (json[field] as List<String>).clear();
      }
      expect(value, image);
      final ModelAiContentCapabilities bounded = image.copyWith(
        maxMessagesPerRequest: 2,
        maxImagesPerRequest: 2,
        maxBytesPerImage: 3,
      );
      expect(
        bounded.copyWith(
          maxMessagesPerRequest: null,
          maxImagesPerRequest: null,
          maxBytesPerImage: null,
        ),
        image,
      );
      final ModelAiContentCapabilities cleared = image.copyWith(
        inputRoles: null,
        imageSourceTypes: null,
        imageMimeTypes: null,
      );
      expect(ModelAiContentCapabilities.fromJson(cleared.toJson()), cleared);
      final Map<String, dynamic> absent = cleared.toJson()
        ..remove('inputRoles')
        ..remove('imageSourceTypes')
        ..remove('imageMimeTypes')
        ..remove('maxMessagesPerRequest')
        ..remove('maxImagesPerRequest')
        ..remove('maxBytesPerImage');
      expect(ModelAiContentCapabilities.fromJson(absent), cleared);
      expect(
        cleared.hashCode,
        ModelAiContentCapabilities.fromJson(absent).hashCode,
      );
      expect(cleared, isNot(image));
      expect(image, isNot(cleared));
    },
  );

  test('capability schema rejects unknown members and retains existing duplicate semantics', () {
    for (final String field in <String>[
      'inputModalities',
      'outputModalities',
      'inputRoles',
      'imageSourceTypes',
      'imageMimeTypes',
    ]) {
      for (final Object? bad in <Object?>[0, 'future', null, <String>[]]) {
        expect(
          () => ModelAiContentCapabilities.fromJson(
            image.toJson()..[field] = <Object?>[bad],
          ),
          throwsFormatException,
        );
      }
      final Map<String, dynamic> duplicate = image.toJson();
      final List<String> values = duplicate[field] as List<String>;
      values.addAll(List<String>.of(values));
      expect(ModelAiContentCapabilities.fromJson(duplicate), image);
    }
    expect(
      () => ModelAiContentCapabilities.fromJson(
        image.toJson()..['outputModalities'] = <String>['image'],
      ),
      throwsFormatException,
    );
    final Map<String, dynamic> input = image.toJson();
    final ModelAiContentCapabilities decoded =
        ModelAiContentCapabilities.fromJson(input);
    (input['imageMimeTypes'] as List<String>).clear();
    expect(decoded, image);
  });

  test(
    'invalid bounds and image fields without image input fail structurally',
    () {
      for (final String field in <String>[
        'maxMessagesPerRequest',
        'maxImagesPerRequest',
        'maxBytesPerImage',
      ]) {
        for (final Object bad in <Object>[0, -1, 1.5, '2', true]) {
          expect(
            () => ModelAiContentCapabilities.fromJson(
              image.toJson()..[field] = bad,
            ),
            throwsFormatException,
          );
        }
      }
      for (final Object Function() invalid in <Object Function()>[
        () => image.copyWith(maxMessagesPerRequest: 0),
        () => image.copyWith(maxImagesPerRequest: -1),
        () => image.copyWith(maxBytesPerImage: 0),
        () => image.copyWith(inputRoles: 'bad'),
        () => image.copyWith(imageSourceTypes: 1),
        () => image.copyWith(imageMimeTypes: <int>{1}),
        () => image.copyWith(maxBytesPerImage: 'bad'),
        () => text.copyWith(imageMimeTypes: <String>{}),
        () => text.copyWith(imageSourceTypes: <EnumAiContentSourceType>{}),
        () => text.copyWith(maxImagesPerRequest: 1),
        () => text.copyWith(maxBytesPerImage: 1),
      ]) {
        expect(invalid, throwsArgumentError);
      }
      expect(
        () => ModelAiContentCapabilities.fromJson(
          text.toJson()..['imageMimeTypes'] = <String>[],
        ),
        throwsFormatException,
      );
      expect(
        () => descriptor().copyWith(
          contentCapabilities: image.copyWith(
            outputModalities: <EnumAiOutputModality>{},
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => ModelAiDescriptor.fromJson(
          descriptor().toJson()
            ..['contentCapabilities'] = image
                .copyWith(outputModalities: <EnumAiOutputModality>{})
                .toJson(),
        ),
        throwsFormatException,
      );
      expect(
        () => descriptor().copyWith(contentCapabilities: 'bad'),
        throwsArgumentError,
      );
      expect(
        () => ModelAiDescriptor.fromJson(
          descriptor().toJson()..['contentCapabilities'] = 1,
        ),
        throwsFormatException,
      );
    },
  );

  test('fake gateway rejects supported-domain images before execution; reports do not certify runtime', () async {
    final ContentFixtureGateway textOnly = ContentFixtureGateway(image, text);
    final AiResult<ModelAiResponse> rejected = await textOnly.infer(mixed);
    expect(rejected, isA<AiFailureResult<ModelAiResponse>>());
    final ModelAiFailure failure =
        (rejected as AiFailureResult<ModelAiResponse>).failure;
    expect(failure.code, EnumAiFailureCode.unsupportedCapability);
    expect(failure.retryable, isFalse);
    expect(textOnly.executions, 0);
    final ContentFixtureGateway unspecified = ContentFixtureGateway(null, text);
    final AiFailureResult<ModelAiResponse> notEstablished =
        await unspecified.infer(textRequest)
            as AiFailureResult<ModelAiResponse>;
    expect(notEstablished.failure.message, contains('not established'));
    expect(unspecified.executions, 0);
    final ContentFixtureGateway runtime = ContentFixtureGateway(
      image,
      image,
      runtimeRejects: true,
    );
    expect(assess(mixed, image, image).status, matches);
    final AiResult<ModelAiResponse> runtimeResult = await runtime.infer(mixed);
    expect(
      (runtimeResult as AiFailureResult<ModelAiResponse>).failure.code,
      EnumAiFailureCode.unsupportedCapability,
    );
    expect(runtime.executions, 1);
    final ContentFixtureGateway matchingText = ContentFixtureGateway(
      text,
      text,
    );
    final AiSuccess<ModelAiResponse> success =
        await matchingText.infer(textRequest) as AiSuccess<ModelAiResponse>;
    expect(success.value.text, isEmpty);
    expect(success.value.requestId, textRequest.requestId);
    expect(success.value.modelId, textRequest.modelId);
  });
}
