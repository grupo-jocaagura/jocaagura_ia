import 'package:jocaagura_ai/jocaagura_ai.dart';

ModelAiContentCapabilities textProfile() => ModelAiContentCapabilities(
  inputModalities: <EnumAiInputModality>{EnumAiInputModality.text},
  outputModalities: <EnumAiOutputModality>{EnumAiOutputModality.text},
  inputRoles: <EnumAiMessageRole>{EnumAiMessageRole.user},
);

ModelAiContentCapabilities imageProfile() => ModelAiContentCapabilities(
  inputModalities: EnumAiInputModality.values.toSet(),
  outputModalities: EnumAiOutputModality.values.toSet(),
  inputRoles: EnumAiMessageRole.values.toSet(),
  imageSourceTypes: EnumAiContentSourceType.values.toSet(),
  imageMimeTypes: <String>{'image/png', 'image/jpeg'},
);

ModelAiImagePart imagePart({ModelAiContentSource? source}) => ModelAiImagePart(
  mimeType: 'image/png',
  source: source ?? ModelAiInlineBytesSource(bytes: <int>[1, 2, 3]),
);

ModelAiRequest contentRequest([List<ModelAiContentPart>? parts]) =>
    ModelAiRequest(
      requestId: 'content-1',
      modelId: 'fixture',
      messages: <ModelAiMessage>[
        ModelAiMessage(
          role: EnumAiMessageRole.user,
          parts:
              parts ??
              <ModelAiContentPart>[
                ModelAiTextPart(text: 'Describe:'),
                imagePart(),
              ],
        ),
      ],
    );
