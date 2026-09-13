// Final fields and defensive copies keep these SDK-only values immutable.
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import '../enums/ai_enums.dart';
import '../internal/content_values.dart';
import '../internal/domain_values.dart';
import 'model_ai_content_source.dart';

/// One ordered, typed input part; unknown variants fail closed.
sealed class ModelAiContentPart {
  const ModelAiContentPart();
  factory ModelAiContentPart.fromJson(Map<String, dynamic> json) {
    final EnumAiInputModality type = decodeAt(
      'type',
      () => readContentEnum(json['type'], EnumAiInputModality.values),
    );
    return switch (type) {
      EnumAiInputModality.text => ModelAiTextPart.fromJson(json),
      EnumAiInputModality.image => ModelAiImagePart.fromJson(json),
    };
  }

  /// Intentionally also the part discriminator: one variant per input modality.
  /// Revisit this mapping if a future modality needs multiple part variants.
  EnumAiInputModality get type;

  /// Descriptive strings only, never provider options or capability overrides.
  Map<String, String> get metadata;
  Map<String, dynamic> toJson();
}

/// Nonempty text; whitespace and Unicode are preserved exactly.
final class ModelAiTextPart extends ModelAiContentPart {
  ModelAiTextPart({
    required this.text,
    Map<String, String> metadata = const <String, String>{},
  }) : metadata = freezeMetadata(metadata) {
    requireText(text, 'text', allowWhitespace: true);
  }
  factory ModelAiTextPart.fromJson(Map<String, dynamic> json) {
    decodeAt('type', () {
      if (json['type'] != 'text') {
        throw const FormatException('Expected text');
      }
    });
    forbidKeys(json, <String>['mimeType', 'source']);
    final Map<String, String> metadata = readMetadata(json);
    return decodeAt(
      'text',
      () => ModelAiTextPart(
        text: readString(json['text'], 'value'),
        metadata: metadata,
      ),
    );
  }
  final String text;
  @override
  final Map<String, String> metadata;
  @override
  EnumAiInputModality get type => EnumAiInputModality.text;
  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type.name,
    'text': text,
    'metadata': metadataJson(metadata),
  };
  ModelAiTextPart copyWith({Object? text = unset, Object? metadata = unset}) =>
      ModelAiTextPart(
        text: requiredUpdate(text, this.text),
        metadata: requiredUpdate(metadata, this.metadata),
      );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelAiTextPart &&
          text == other.text &&
          metadataEquals(metadata, other.metadata);
  @override
  int get hashCode => Object.hash(type, text, metadataHash(metadata));
}

/// Image declaration; MIME and source bytes are not checked against a codec.
final class ModelAiImagePart extends ModelAiContentPart {
  ModelAiImagePart({
    required String mimeType,
    required this.source,
    Map<String, String> metadata = const <String, String>{},
  }) : mimeType = normalizeImageMime(mimeType),
       metadata = freezeMetadata(metadata);
  factory ModelAiImagePart.fromJson(Map<String, dynamic> json) {
    decodeAt('type', () {
      if (json['type'] != 'image') {
        throw const FormatException('Expected image');
      }
    });
    forbidKeys(json, <String>['text']);
    final String mime = decodeAt(
      'mimeType',
      () => normalizeImageMime(readString(json['mimeType'], 'value')),
    );
    final ModelAiContentSource source = decodeAt(
      'source',
      () => ModelAiContentSource.fromJson(readObject(json['source'], 'value')),
    );
    return ModelAiImagePart(
      mimeType: mime,
      source: source,
      metadata: readMetadata(json),
    );
  }

  /// Lowercase ASCII image MIME, without parameters or wildcard aliases.
  final String mimeType;
  final ModelAiContentSource source;
  @override
  final Map<String, String> metadata;
  @override
  EnumAiInputModality get type => EnumAiInputModality.image;
  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type.name,
    'mimeType': mimeType,
    'source': source.toJson(),
    'metadata': metadataJson(metadata),
  };
  ModelAiImagePart copyWith({
    Object? mimeType = unset,
    Object? source = unset,
    Object? metadata = unset,
  }) => ModelAiImagePart(
    mimeType: requiredUpdate(mimeType, this.mimeType),
    source: requiredUpdate(source, this.source),
    metadata: requiredUpdate(metadata, this.metadata),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelAiImagePart &&
          mimeType == other.mimeType &&
          source == other.source &&
          metadataEquals(metadata, other.metadata);
  @override
  int get hashCode =>
      Object.hash(type, mimeType, source, metadataHash(metadata));
}
