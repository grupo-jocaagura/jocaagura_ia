// This final value type uses final fields and defensive collection copies.
// The annotation-based lint requires package:meta; the domain is SDK-only.
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import '../enums/ai_enums.dart';
import '../internal/domain_values.dart';
import 'model_ai_requirements.dart';
import 'model_ai_source.dart';

/// An installable artifact configuration obtained through model management.
final class ModelAiDescriptor {
  /// Creates a validated immutable value; invalid arguments throw ArgumentError.
  ModelAiDescriptor({
    required this.id,
    required this.displayName,
    required this.version,
    required Set<EnumAiCapability> capabilities,
    required this.requirements,
    required this.source,
  }) : capabilities = Set<EnumAiCapability>.unmodifiable(capabilities) {
    requireText(id, 'id');
    requireText(displayName, 'displayName');
    requireText(version, 'version');
    if (this.capabilities.isEmpty) {
      throw ArgumentError.value(
        capabilities,
        'capabilities',
        'At least one capability is required',
      );
    }
  }

  /// Decodes JSON, throwing FormatException for invalid or missing fields.
  factory ModelAiDescriptor.fromJson(Map<String, dynamic> json) => decodeModel(
    () => ModelAiDescriptor(
      id: readString(json['id'], 'id'),
      displayName: readString(json['displayName'], 'displayName'),
      version: readString(json['version'], 'version'),
      capabilities: readList(json['capabilities'], 'capabilities')
          .map(
            (Object? value) =>
                readEnum(value, EnumAiCapability.values, 'capabilities'),
          )
          .toSet(),
      requirements: ModelAiRequirements.fromJson(
        readObject(json['requirements'], 'requirements'),
      ),
      source: ModelAiSource.fromJson(readObject(json['source'], 'source')),
    ),
  );

  /// Unique logical identifier used in inference requests.
  final String id;

  /// Human-readable nonblank model name.
  final String displayName;

  /// Opaque nonblank artifact version.
  final String version;

  /// Nonempty capabilities, compared without ordering.
  final Set<EnumAiCapability> capabilities;

  /// Known resource requirements.
  final ModelAiRequirements requirements;

  /// Acquisition location and integrity metadata.
  final ModelAiSource source;

  /// Returns independent JSON data with deterministic keys and enum names.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'displayName': displayName,
    'version': version,
    'capabilities':
        (capabilities.map((EnumAiCapability value) => value.name).toList()
          ..sort()),
    'requirements': requirements.toJson(),
    'source': source.toJson(),
  };

  /// Copies this value. Omitted nullable fields are preserved; null clears them.
  ModelAiDescriptor copyWith({
    String? id,
    String? displayName,
    String? version,
    Set<EnumAiCapability>? capabilities,
    ModelAiRequirements? requirements,
    ModelAiSource? source,
  }) => ModelAiDescriptor(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    version: version ?? this.version,
    capabilities: capabilities ?? this.capabilities,
    requirements: requirements ?? this.requirements,
    source: source ?? this.source,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelAiDescriptor &&
          id == other.id &&
          displayName == other.displayName &&
          version == other.version &&
          setEquals(capabilities, other.capabilities) &&
          requirements == other.requirements &&
          source == other.source;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    displayName,
    version,
    Object.hashAllUnordered(capabilities),
    requirements,
    source,
  ]);
}
