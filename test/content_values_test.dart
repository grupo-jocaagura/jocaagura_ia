import 'dart:convert';
import 'dart:typed_data';

import 'package:jocaagura_ai/jocaagura_ai.dart';
import 'package:test/test.dart';

import 'fixtures/content_fixtures.dart';
import 'fixtures/domain_fixtures.dart' show descriptor, valueContract;

void main() {
  final ModelAiTextPart text = ModelAiTextPart(
    text: ' \n🙂e\u0301 ',
    metadata: <String, String>{'z': '', 'a': 'label'},
  );
  final ModelAiInlineBytesSource bytes = ModelAiInlineBytesSource(
    bytes: <int>[1, 2, 3],
  );
  final ModelAiLocalFileSource file = ModelAiLocalFileSource(
    path: 'fixtures/does-not-exist.png',
  );
  final ModelAiImagePart image = imagePart();
  final ModelAiContentCapabilities profile = imageProfile();
  final ModelAiContentCompatibility report = ModelAiContentCompatibility(
    status: EnumAiContentCompatibilityStatus.undetermined,
    reasons: <String>['model unknown'],
  );

  valueContract<ModelAiTextPart>(
    'text part',
    value: text,
    encode: (ModelAiTextPart v) => v.toJson(),
    decode: ModelAiTextPart.fromJson,
    copy: (ModelAiTextPart v) => v.copyWith(),
    changed: <ModelAiTextPart>[
      text.copyWith(text: 'other'),
      text.copyWith(metadata: <String, String>{}),
    ],
  );
  valueContract<ModelAiInlineBytesSource>(
    'inline bytes',
    value: bytes,
    encode: (ModelAiInlineBytesSource v) => v.toJson(),
    decode: ModelAiInlineBytesSource.fromJson,
    copy: (ModelAiInlineBytesSource v) => v.copyWith(),
    changed: <ModelAiInlineBytesSource>[
      bytes.copyWith(bytes: <int>[3, 2, 1]),
    ],
  );
  valueContract<ModelAiLocalFileSource>(
    'local file',
    value: file,
    encode: (ModelAiLocalFileSource v) => v.toJson(),
    decode: ModelAiLocalFileSource.fromJson,
    copy: (ModelAiLocalFileSource v) => v.copyWith(),
    changed: <ModelAiLocalFileSource>[
      file.copyWith(path: './fixtures/does-not-exist.png'),
    ],
  );
  valueContract<ModelAiImagePart>(
    'image part',
    value: image,
    encode: (ModelAiImagePart v) => v.toJson(),
    decode: ModelAiImagePart.fromJson,
    copy: (ModelAiImagePart v) => v.copyWith(),
    changed: <ModelAiImagePart>[
      image.copyWith(mimeType: 'image/jpeg'),
      image.copyWith(source: file),
      image.copyWith(metadata: <String, String>{'label': 'new'}),
    ],
  );
  valueContract<ModelAiContentCapabilities>(
    'content capabilities',
    value: profile,
    encode: (ModelAiContentCapabilities v) => v.toJson(),
    decode: ModelAiContentCapabilities.fromJson,
    copy: (ModelAiContentCapabilities v) => v.copyWith(),
    changed: <ModelAiContentCapabilities>[
      profile.copyWith(
        inputModalities: <EnumAiInputModality>{EnumAiInputModality.image},
      ),
      profile.copyWith(outputModalities: <EnumAiOutputModality>{}),
      profile.copyWith(inputRoles: null),
      profile.copyWith(imageSourceTypes: null),
      profile.copyWith(imageMimeTypes: null),
      profile.copyWith(maxMessagesPerRequest: 2),
      profile.copyWith(maxImagesPerRequest: 2),
      profile.copyWith(maxBytesPerImage: 2),
    ],
  );
  valueContract<ModelAiContentCompatibility>(
    'compatibility report',
    value: report,
    encode: (ModelAiContentCompatibility v) => v.toJson(),
    decode: ModelAiContentCompatibility.fromJson,
    copy: (ModelAiContentCompatibility v) => v.copyWith(),
    changed: <ModelAiContentCompatibility>[
      report.copyWith(status: EnumAiContentCompatibilityStatus.unsupported),
      report.copyWith(reasons: <String>['other']),
    ],
  );
  final ModelAiRequest mixed = contentRequest(<ModelAiContentPart>[
    text,
    image,
    image.copyWith(source: file),
    text,
  ]);
  valueContract<ModelAiRequest>(
    'mixed request',
    value: mixed,
    encode: (ModelAiRequest v) => v.toJson(),
    decode: ModelAiRequest.fromJson,
    copy: (ModelAiRequest v) => v.copyWith(),
    changed: <ModelAiRequest>[
      contentRequest(mixed.messages.single.parts.reversed.toList()),
    ],
  );
  final ModelAiDescriptor described = descriptor().copyWith(
    contentCapabilities: profile,
  );
  valueContract<ModelAiDescriptor>(
    'descriptor with profile',
    value: described,
    encode: (ModelAiDescriptor v) => v.toJson(),
    decode: ModelAiDescriptor.fromJson,
    copy: (ModelAiDescriptor v) => v.copyWith(),
    changed: <ModelAiDescriptor>[described.copyWith(contentCapabilities: null)],
  );

  test(
    'legacy JSON normalizes to one part, canonical writers never emit content',
    () {
      final Map<String, dynamic> legacy = <String, dynamic>{
        'role': 'user',
        'content': ' \n🙂 ',
      };
      final ModelAiMessage migrated = ModelAiMessage.fromJson(legacy);
      expect(
        migrated,
        ModelAiMessage.text(role: EnumAiMessageRole.user, text: ' \n🙂 '),
      );
      expect(migrated.toJson(), <String, dynamic>{
        'role': 'user',
        'parts': <Object>[
          <String, dynamic>{
            'type': 'text',
            'text': ' \n🙂 ',
            'metadata': <String, String>{},
          },
        ],
      });
      expect(ModelAiMessage.fromJson(migrated.toJson()), migrated);
      for (final EnumAiMessageRole role in EnumAiMessageRole.values) {
        expect(
          ModelAiMessage(
            role: role,
            parts: <ModelAiContentPart>[image],
          ).parts.single,
          image,
        );
      }
      final Map<String, dynamic> oldDescriptor = descriptor().toJson()
        ..remove('contentCapabilities');
      expect(ModelAiDescriptor.fromJson(oldDescriptor), descriptor());
      expect(
        ModelAiDescriptor.fromJson(oldDescriptor)
            .toJson()['contentCapabilities'],
        isNull,
      );
    },
  );

  test('missing, ambiguous and invalid message content fail closed', () {
    for (final Map<String, dynamic> invalid in <Map<String, dynamic>>[
      <String, dynamic>{},
      <String, dynamic>{'content': null},
      <String, dynamic>{'content': ''},
      <String, dynamic>{'content': 1},
      <String, dynamic>{'parts': null},
      <String, dynamic>{'parts': <Object>[]},
      <String, dynamic>{
        'parts': <Object?>[null],
      },
      <String, dynamic>{
        'parts': <Object>[1],
      },
      <String, dynamic>{'parts': 'x'},
      <String, dynamic>{'content': 'x', 'parts': null},
      <String, dynamic>{
        'content': null,
        'parts': <Object>[text.toJson()],
      },
      <String, dynamic>{
        'content': text.text,
        'parts': <Object>[text.toJson()],
      },
    ]) {
      expect(
        () => ModelAiMessage.fromJson(<String, dynamic>{
          'role': 'user',
          ...invalid,
        }),
        throwsFormatException,
      );
    }
    expect(
      () => ModelAiMessage(
        role: EnumAiMessageRole.user,
        parts: <ModelAiContentPart>[],
      ),
      throwsArgumentError,
    );
    expect(() => text.copyWith(text: ''), throwsArgumentError);
    expect(
      () => mixed.messages.single.copyWith(parts: <ModelAiContentPart>[]),
      throwsArgumentError,
    );
  });

  final List<
    ({
      Map<String, dynamic> json,
      Object Function(Map<String, dynamic>) decode,
      List<String> required,
    })
  >
  schemas =
      <
        ({
          Map<String, dynamic> json,
          Object Function(Map<String, dynamic>) decode,
          List<String> required,
        })
      >[
        (
          json: text.toJson(),
          decode: ModelAiTextPart.fromJson,
          required: <String>['type', 'text'],
        ),
        (
          json: image.toJson(),
          decode: ModelAiImagePart.fromJson,
          required: <String>['type', 'mimeType', 'source'],
        ),
        (
          json: bytes.toJson(),
          decode: ModelAiInlineBytesSource.fromJson,
          required: <String>['type', 'bytesBase64'],
        ),
        (
          json: file.toJson(),
          decode: ModelAiLocalFileSource.fromJson,
          required: <String>['type', 'path'],
        ),
        (
          json: profile.toJson(),
          decode: ModelAiContentCapabilities.fromJson,
          required: <String>['inputModalities', 'outputModalities'],
        ),
        (
          json: report.toJson(),
          decode: ModelAiContentCompatibility.fromJson,
          required: <String>['status', 'reasons'],
        ),
      ];
  for (int schema = 0; schema < schemas.length; schema++) {
    final ({
      Map<String, dynamic> json,
      Object Function(Map<String, dynamic>) decode,
      List<String> required,
    })
    item = schemas[schema];
    test(
      'required schema fields $schema reject absence, null and wrong types',
      () {
        for (final String key in item.required) {
          expect(
            () => item.decode(Map<String, dynamic>.of(item.json)..remove(key)),
            throwsFormatException,
          );
          for (final Object? bad in <Object?>[null, 17, false]) {
            expect(
              () =>
                  item.decode(Map<String, dynamic>.of(item.json)..[key] = bad),
              throwsFormatException,
            );
          }
        }
      },
    );
  }

  test(
    'dispatchers reject unknown discriminators and all cross-variant fields',
    () {
      for (final Object? bad in <Object?>[
        null,
        0,
        'audio',
        'Text',
        'remoteDownload',
        <String>[],
      ]) {
        expect(
          () => ModelAiContentPart.fromJson(<String, dynamic>{'type': bad}),
          throwsFormatException,
        );
        expect(
          () => ModelAiContentSource.fromJson(<String, dynamic>{'type': bad}),
          throwsFormatException,
        );
        expect(
          () => ModelAiMessage.fromJson(<String, dynamic>{
            'role': bad,
            'content': 'x',
          }),
          throwsFormatException,
        );
        expect(
          () => ModelAiContentCompatibility.fromJson(
            report.toJson()..['status'] = bad,
          ),
          throwsFormatException,
        );
      }
      for (final ({
            Map<String, dynamic> json,
            Object Function(Map<String, dynamic>) decode,
            List<String> keys,
          })
          item
          in <
            ({
              Map<String, dynamic> json,
              Object Function(Map<String, dynamic>) decode,
              List<String> keys,
            })
          >[
            (
              json: text.toJson(),
              decode: ModelAiContentPart.fromJson,
              keys: <String>['mimeType', 'source'],
            ),
            (
              json: image.toJson(),
              decode: ModelAiContentPart.fromJson,
              keys: <String>['text'],
            ),
            (
              json: bytes.toJson(),
              decode: ModelAiContentSource.fromJson,
              keys: <String>['path'],
            ),
            (
              json: file.toJson(),
              decode: ModelAiContentSource.fromJson,
              keys: <String>['bytesBase64'],
            ),
          ]) {
        for (final String key in item.keys) {
          for (final Object? bad in <Object?>[null, 'payload']) {
            expect(
              () =>
                  item.decode(Map<String, dynamic>.of(item.json)..[key] = bad),
              throwsFormatException,
            );
          }
        }
      }
    },
  );

  test('canonical Base64 validates bytes without interpreting the image', () {
    expect(bytes.toJson()['bytesBase64'], 'AQID');
    expect(
      image.source,
      bytes,
    ); // Intentionally not a PNG; no codec is invoked.
    for (final String good in <String>['AQ==', 'AQI=', 'AQID', '+/8=']) {
      expect(
        ModelAiContentSource.fromJson(<String, dynamic>{
          'type': 'inlineBytes',
          'bytesBase64': good,
        }).toJson()['bytesBase64'],
        good,
      );
    }
    for (final String bad in <String>[
      '',
      'AQ',
      'AQI',
      'AR==',
      '-_8=',
      'AQ==\n',
      ' AQ==',
      'AQ===',
      '%%%secret',
      'data:image/png;base64,AQ==',
    ]) {
      expect(
        () => ModelAiContentSource.fromJson(
          bytes.toJson()..['bytesBase64'] = bad,
        ),
        throwsFormatException,
      );
    }
    for (final List<int> bad in <List<int>>[
      <int>[],
      <int>[-1],
      <int>[256],
    ]) {
      expect(() => ModelAiInlineBytesSource(bytes: bad), throwsArgumentError);
      expect(() => bytes.copyWith(bytes: bad), throwsArgumentError);
    }
  });

  test(
    'MIME normalization and lexical paths do not imply format or locality',
    () {
      expect(image.copyWith(mimeType: 'IMAGE/PNG'), image);
      expect(
        image.copyWith(mimeType: 'image/jpg'),
        isNot(image.copyWith(mimeType: 'image/jpeg')),
      );
      expect(
        image.copyWith(mimeType: 'image/x-vendor.foo+bar').mimeType,
        'image/x-vendor.foo+bar',
      );
      for (final String bad in <String>[
        '',
        ' image/png',
        'image/png ',
        'image/png\n',
        'image/',
        'text/plain',
        'image/*',
        'image/png;charset=utf-8',
        'image/🙂',
        'İMAGE/png',
      ]) {
        expect(() => image.copyWith(mimeType: bad), throwsArgumentError);
        expect(
          () => ModelAiContentPart.fromJson(image.toJson()..['mimeType'] = bad),
          throwsFormatException,
        );
      }
      for (final String good in <String>[
        'a.png',
        '/not/a/real/file.png',
        r'C:\pictures\image.png',
        '../sample.png',
        ' ./sample.png ',
      ]) {
        expect(
          ModelAiLocalFileSource.fromJson(file.copyWith(path: good).toJson())
              .path,
          good,
        );
      }
      for (final String bad in <String>[
        '',
        ' ',
        'a\u0000b',
        'https://host/a',
        'DATA:x',
        'FILE:/a',
        '//server/a',
        r'\\server\a',
      ]) {
        expect(() => file.copyWith(path: bad), throwsArgumentError);
        expect(
          () => ModelAiContentSource.fromJson(file.toJson()..['path'] = bad),
          throwsFormatException,
        );
      }
    },
  );

  test('metadata is flat, descriptive, normalized only by key ordering', () {
    expect(
      ModelAiTextPart.fromJson(text.toJson()..remove('metadata')).metadata,
      isEmpty,
    );
    expect(
      ModelAiImagePart.fromJson(image.toJson()..remove('metadata')).metadata,
      isEmpty,
    );
    final ModelAiTextPart reordered = text.copyWith(
      metadata: <String, String>{'a': 'label', 'z': ''},
    );
    expect(reordered, text);
    expect(reordered.hashCode, text.hashCode);
    expect(jsonEncode(reordered.toJson()), jsonEncode(text.toJson()));
    for (final Object? bad in <Object?>[
      null,
      42,
      <Object>[],
      <String, dynamic>{'x': null},
      <String, dynamic>{'x': 2},
      <String, dynamic>{'x': <String>[]},
      <String, String>{' ': 'x'},
    ]) {
      expect(
        () => ModelAiTextPart.fromJson(text.toJson()..['metadata'] = bad),
        throwsFormatException,
      );
      expect(
        () => ModelAiImagePart.fromJson(image.toJson()..['metadata'] = bad),
        throwsFormatException,
      );
    }
    expect(
      () => text.copyWith(metadata: <String, String>{'': 'x'}),
      throwsArgumentError,
    );
  });

  test('collections, typed buffers and exported JSON cannot mutate values', () {
    final Uint8List inputBytes = Uint8List.fromList(<int>[1, 2, 3]);
    final ModelAiInlineBytesSource source = ModelAiInlineBytesSource(
      bytes: inputBytes,
    );
    inputBytes[0] = 9;
    expect(source, bytes);
    expect(() => source.bytes[0] = 7, throwsUnsupportedError);
    final Map<String, String> metadata = <String, String>{'label': 'x'};
    final ModelAiImagePart value = image.copyWith(metadata: metadata);
    metadata.clear();
    expect(value.metadata, <String, String>{'label': 'x'});
    expect(() => value.metadata.clear(), throwsUnsupportedError);
    final List<ModelAiContentPart> parts = <ModelAiContentPart>[text, value];
    final ModelAiMessage msg = ModelAiMessage(
      role: EnumAiMessageRole.user,
      parts: parts,
    );
    final int hash = msg.hashCode;
    parts.clear();
    expect(msg.parts, hasLength(2));
    expect(() => msg.parts.clear(), throwsUnsupportedError);
    final Map<String, dynamic> json = msg.toJson();
    final List<dynamic> jsonParts = json['parts'] as List<dynamic>;
    final Map<String, dynamic> jsonImage = jsonParts[1] as Map<String, dynamic>;
    (jsonImage['source'] as Map<String, dynamic>)['bytesBase64'] = 'changed';
    (jsonImage['metadata'] as Map<String, String>).clear();
    jsonParts.clear();
    expect(msg.hashCode, hash);
    final Map<String, dynamic> incoming = msg.toJson();
    final ModelAiMessage decoded = ModelAiMessage.fromJson(incoming);
    (incoming['parts'] as List<dynamic>).clear();
    expect(decoded, msg);
    final List<String> reasons = <String>['first'];
    final ModelAiContentCompatibility result = report.copyWith(
      reasons: reasons,
    );
    reasons.clear();
    expect(result.reasons, <String>['first']);
    expect(() => result.reasons.clear(), throwsUnsupportedError);
    (result.toJson()['reasons'] as List<String>).clear();
    expect(result.reasons, <String>['first']);
  });

  test(
    'text part boundaries are semantic and no implicit flattening occurs',
    () {
      expect(
        contentRequest(<ModelAiContentPart>[
          ModelAiTextPart(text: 'a'),
          ModelAiTextPart(text: 'b'),
        ]),
        isNot(
          contentRequest(<ModelAiContentPart>[ModelAiTextPart(text: 'ab')]),
        ),
      );
      expect(text, isNot(image));
      expect(file, isNot(bytes));
    },
  );

  test('nested errors identify field/index without leaking source data', () {
    final Map<String, dynamic> json = contentRequest().toJson();
    final Map<String, dynamic> message =
        (json['messages'] as List<dynamic>).single as Map<String, dynamic>;
    final Map<String, dynamic> badPart =
        (message['parts'] as List<dynamic>)[1] as Map<String, dynamic>;
    (badPart['source'] as Map<String, dynamic>)['bytesBase64'] =
        'private raw payload!';
    expect(
      () => ModelAiRequest.fromJson(json),
      throwsA(
        isA<FormatException>()
            .having(
              (FormatException e) => e.message,
              'path',
              contains('messages: [0]: parts: [1]: source: bytesBase64'),
            )
            .having(
              (FormatException e) => e.toString(),
              'redaction',
              isNot(contains('private raw payload')),
            ),
      ),
    );
  });

  test(
    'explicit null/wrong-type copies never clear required content fields',
    () {
      final ModelAiMessage msg = mixed.messages.single;
      for (final Object? bad in <Object?>[null, 42]) {
        for (final Object Function() copy in <Object Function()>[
          () => text.copyWith(text: bad),
          () => text.copyWith(metadata: bad),
          () => image.copyWith(mimeType: bad),
          () => image.copyWith(source: bad),
          () => image.copyWith(metadata: bad),
          () => file.copyWith(path: bad),
          () => bytes.copyWith(bytes: bad),
          () => msg.copyWith(parts: bad),
          () => msg.copyWith(role: bad),
          () => profile.copyWith(inputModalities: bad),
          () => profile.copyWith(outputModalities: bad),
          () => report.copyWith(status: bad),
          () => report.copyWith(reasons: bad),
        ]) {
          expect(copy, throwsArgumentError);
        }
      }
    },
  );

  test('report invariants, status variants and reason order round trip', () {
    for (final EnumAiContentCompatibilityStatus status
        in EnumAiContentCompatibilityStatus.values) {
      final ModelAiContentCompatibility value = ModelAiContentCompatibility(
        status: status,
        reasons:
            status == EnumAiContentCompatibilityStatus.meetsDeclaredConstraints
            ? <String>[]
            : <String>['a', 'b'],
      );
      expect(ModelAiContentCompatibility.fromJson(value.toJson()), value);
      expect(() => value.copyWith(reasons: <String>[' ']), throwsArgumentError);
    }
    expect(() => report.copyWith(reasons: <String>[]), throwsArgumentError);
    expect(
      () => report.copyWith(
        status: EnumAiContentCompatibilityStatus.meetsDeclaredConstraints,
      ),
      throwsArgumentError,
    );
    expect(
      report.copyWith(reasons: <String>['a', 'b']),
      isNot(report.copyWith(reasons: <String>['b', 'a'])),
    );
  });
}
