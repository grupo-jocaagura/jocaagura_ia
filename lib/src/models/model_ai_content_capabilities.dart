// Final fields and defensive copies keep this SDK-only value immutable.
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import '../enums/ai_enums.dart';
import '../internal/content_values.dart';
import '../internal/domain_values.dart';

/// Model or backend declarations, never a runtime certification.
final class ModelAiContentCapabilities {
  ModelAiContentCapabilities({
    required Set<EnumAiInputModality> inputModalities,
    required Set<EnumAiOutputModality> outputModalities,
    Set<EnumAiMessageRole>? inputRoles,
    Set<EnumAiContentSourceType>? imageSourceTypes,
    Set<String>? imageMimeTypes,
    this.maxMessagesPerRequest,
    this.maxImagesPerRequest,
    this.maxBytesPerImage,
  }) : inputModalities = Set<EnumAiInputModality>.unmodifiable(inputModalities),
       outputModalities = Set<EnumAiOutputModality>.unmodifiable(
         outputModalities,
       ),
       inputRoles = _freeze(inputRoles),
       imageSourceTypes = _freeze(imageSourceTypes),
       imageMimeTypes = imageMimeTypes == null
           ? null
           : Set<String>.unmodifiable(imageMimeTypes.map(normalizeImageMime)) {
    requireCount(
      maxMessagesPerRequest,
      'maxMessagesPerRequest',
      positive: true,
    );
    requireCount(maxImagesPerRequest, 'maxImagesPerRequest', positive: true);
    requireCount(maxBytesPerImage, 'maxBytesPerImage', positive: true);
    if (!this.inputModalities.contains(EnumAiInputModality.image) &&
        (this.imageSourceTypes != null ||
            this.imageMimeTypes != null ||
            maxImagesPerRequest != null ||
            maxBytesPerImage != null)) {
      throw ArgumentError('Image-specific fields require image input');
    }
  }

  factory ModelAiContentCapabilities.fromJson(Map<String, dynamic> json) =>
      decodeModel(
        () => ModelAiContentCapabilities(
          inputModalities: _enumSet(
            json,
            'inputModalities',
            EnumAiInputModality.values,
          ),
          outputModalities: _enumSet(
            json,
            'outputModalities',
            EnumAiOutputModality.values,
          ),
          inputRoles: json['inputRoles'] == null
              ? null
              : _enumSet(json, 'inputRoles', EnumAiMessageRole.values),
          imageSourceTypes: json['imageSourceTypes'] == null
              ? null
              : _enumSet(
                  json,
                  'imageSourceTypes',
                  EnumAiContentSourceType.values,
                ),
          imageMimeTypes: json['imageMimeTypes'] == null
              ? null
              : decodeAt(
                  'imageMimeTypes',
                  () => readContentList(
                    json['imageMimeTypes'],
                    (Object? value) =>
                        normalizeImageMime(readString(value, 'value')),
                  ).toSet(),
                ),
          maxMessagesPerRequest: _limit(json, 'maxMessagesPerRequest'),
          maxImagesPerRequest: _limit(json, 'maxImagesPerRequest'),
          maxBytesPerImage: _limit(json, 'maxBytesPerImage'),
        ),
      );

  /// Required sets. Empty explicitly declares no accepted input/output.
  final Set<EnumAiInputModality> inputModalities;
  final Set<EnumAiOutputModality> outputModalities;

  /// Null allowlists mean unknown; empty sets explicitly allow nothing.
  final Set<EnumAiMessageRole>? inputRoles;
  final Set<EnumAiContentSourceType>? imageSourceTypes;
  final Set<String>? imageMimeTypes;

  /// Null maxima mean no bound declared here, not unlimited runtime resources.
  final int? maxMessagesPerRequest;
  final int? maxImagesPerRequest;
  final int? maxBytesPerImage;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'inputModalities': _names(inputModalities),
    'outputModalities': _names(outputModalities),
    'inputRoles': inputRoles == null ? null : _names(inputRoles!),
    'imageSourceTypes': imageSourceTypes == null
        ? null
        : _names(imageSourceTypes!),
    'imageMimeTypes': imageMimeTypes == null
        ? null
        : (imageMimeTypes!.toList()..sort()),
    'maxMessagesPerRequest': maxMessagesPerRequest,
    'maxImagesPerRequest': maxImagesPerRequest,
    'maxBytesPerImage': maxBytesPerImage,
  };

  ModelAiContentCapabilities copyWith({
    Object? inputModalities = unset,
    Object? outputModalities = unset,
    Object? inputRoles = unset,
    Object? imageSourceTypes = unset,
    Object? imageMimeTypes = unset,
    Object? maxMessagesPerRequest = unset,
    Object? maxImagesPerRequest = unset,
    Object? maxBytesPerImage = unset,
  }) => ModelAiContentCapabilities(
    inputModalities: requiredUpdate(inputModalities, this.inputModalities),
    outputModalities: requiredUpdate(outputModalities, this.outputModalities),
    inputRoles: nullableUpdate(inputRoles, this.inputRoles),
    imageSourceTypes: nullableUpdate(imageSourceTypes, this.imageSourceTypes),
    imageMimeTypes: nullableUpdate(imageMimeTypes, this.imageMimeTypes),
    maxMessagesPerRequest: nullableUpdate(
      maxMessagesPerRequest,
      this.maxMessagesPerRequest,
    ),
    maxImagesPerRequest: nullableUpdate(
      maxImagesPerRequest,
      this.maxImagesPerRequest,
    ),
    maxBytesPerImage: nullableUpdate(maxBytesPerImage, this.maxBytesPerImage),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelAiContentCapabilities &&
          setEquals(inputModalities, other.inputModalities) &&
          setEquals(outputModalities, other.outputModalities) &&
          _nullableEquals(inputRoles, other.inputRoles) &&
          _nullableEquals(imageSourceTypes, other.imageSourceTypes) &&
          _nullableEquals(imageMimeTypes, other.imageMimeTypes) &&
          maxMessagesPerRequest == other.maxMessagesPerRequest &&
          maxImagesPerRequest == other.maxImagesPerRequest &&
          maxBytesPerImage == other.maxBytesPerImage;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(inputModalities),
    Object.hashAllUnordered(outputModalities),
    _setHash(inputRoles),
    _setHash(imageSourceTypes),
    _setHash(imageMimeTypes),
    maxMessagesPerRequest,
    maxImagesPerRequest,
    maxBytesPerImage,
  );

  static Set<T>? _freeze<T>(Set<T>? values) =>
      values == null ? null : Set<T>.unmodifiable(values);
  static bool _nullableEquals<T>(Set<T>? a, Set<T>? b) =>
      a == null || b == null ? a == b : setEquals(a, b);
  static int? _setHash<T>(Set<T>? values) =>
      values == null ? null : Object.hashAllUnordered(values);
  static List<String> _names<T extends Enum>(Set<T> values) =>
      values.map((T value) => value.name).toList()..sort();
  static Set<T> _enumSet<T extends Enum>(
    Map<String, dynamic> json,
    String field,
    List<T> values,
  ) => decodeAt(
    field,
    () => readContentList(
      json[field],
      (Object? value) => readContentEnum(value, values),
    ).toSet(),
  );
  static int? _limit(Map<String, dynamic> json, String field) =>
      decodeAt(field, () {
        final int? value = readOptionalInt(json[field], 'value');
        requireCount(value, field, positive: true);
        return value;
      });
}
