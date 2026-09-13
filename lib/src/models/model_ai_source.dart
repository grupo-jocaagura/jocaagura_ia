// This final value type uses final fields and defensive collection copies.
// The annotation-based lint requires package:meta; the domain is SDK-only.
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import '../enums/ai_enums.dart';
import '../internal/domain_values.dart';

/// An exclusive acquisition location with optional or required integrity metadata.
final class ModelAiSource {
  /// Creates a validated immutable value; invalid arguments throw ArgumentError.
  ModelAiSource({
    required this.type,
    this.path,
    this.assetPath,
    this.url,
    String? expectedSha256,
  }) : expectedSha256 = expectedSha256?.toLowerCase() {
    final bool validLocation = switch (type) {
      EnumAiSourceType.localFile =>
        path != null && assetPath == null && url == null,
      EnumAiSourceType.bundledAsset =>
        assetPath != null && path == null && url == null,
      EnumAiSourceType.remoteDownload =>
        url != null &&
            path == null &&
            assetPath == null &&
            expectedSha256 != null,
    };
    if (!validLocation) {
      throw ArgumentError(
        'Source requires exactly its matching location and download integrity metadata',
      );
    }
    if (path != null) {
      requireText(path!, 'path');
    }
    if (assetPath != null) {
      requireText(assetPath!, 'assetPath');
    }
    if (url != null) {
      final Uri? parsed = Uri.tryParse(url!);
      if (parsed == null ||
          parsed.scheme != 'https' ||
          parsed.host.isEmpty ||
          parsed.userInfo.isNotEmpty ||
          parsed.hasFragment) {
        throw ArgumentError.value(
          url,
          'url',
          'An absolute HTTPS URL with empty userInfo and no fragment is required',
        );
      }
    }
    if (this.expectedSha256 != null &&
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(this.expectedSha256!)) {
      throw ArgumentError.value(
        expectedSha256,
        'expectedSha256',
        'Expected 64 hexadecimal characters',
      );
    }
  }

  /// Acquires an existing file; integrity metadata is optional.
  factory ModelAiSource.localFile({
    required String path,
    String? expectedSha256,
  }) => ModelAiSource(
    type: EnumAiSourceType.localFile,
    path: path,
    expectedSha256: expectedSha256,
  );

  /// Acquires an application-bundled resource.
  factory ModelAiSource.bundledAsset({
    required String assetPath,
    String? expectedSha256,
  }) => ModelAiSource(
    type: EnumAiSourceType.bundledAsset,
    assetPath: assetPath,
    expectedSha256: expectedSha256,
  );

  /// Downloads a resource whose expected SHA-256 must be known in advance.
  factory ModelAiSource.remoteDownload({
    required String url,
    required String expectedSha256,
  }) => ModelAiSource(
    type: EnumAiSourceType.remoteDownload,
    url: url,
    expectedSha256: expectedSha256,
  );

  /// Decodes JSON, throwing FormatException for invalid or missing fields.
  factory ModelAiSource.fromJson(Map<String, dynamic> json) => decodeModel(
    () => ModelAiSource(
      type: readEnum(json['type'], EnumAiSourceType.values, 'type'),
      path: readOptionalString(json['path'], 'path'),
      assetPath: readOptionalString(json['assetPath'], 'assetPath'),
      url: readOptionalString(json['url'], 'url'),
      expectedSha256: readOptionalString(
        json['expectedSha256'],
        'expectedSha256',
      ),
    ),
  );

  /// Acquisition kind; remoteDownload still means local inference.
  final EnumAiSourceType type;

  /// Required only for a local file.
  final String? path;

  /// Required only for a bundled asset.
  final String? assetPath;

  /// Required only for a remote HTTPS download.
  final String? url;

  /// Lowercase SHA-256; required for remote downloads.
  final String? expectedSha256;

  /// Returns independent JSON data with deterministic keys and enum names.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type.name,
    'path': path,
    'assetPath': assetPath,
    'url': url,
    'expectedSha256': expectedSha256,
  };

  /// Copies this value. Omitted nullable fields are preserved; null clears them.
  ModelAiSource copyWith({
    EnumAiSourceType? type,
    Object? path = unset,
    Object? assetPath = unset,
    Object? url = unset,
    Object? expectedSha256 = unset,
  }) => ModelAiSource(
    type: type ?? this.type,
    path: nullableUpdate<String>(path, this.path),
    assetPath: nullableUpdate<String>(assetPath, this.assetPath),
    url: nullableUpdate<String>(url, this.url),
    expectedSha256: nullableUpdate<String>(expectedSha256, this.expectedSha256),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelAiSource &&
          type == other.type &&
          path == other.path &&
          assetPath == other.assetPath &&
          url == other.url &&
          expectedSha256 == other.expectedSha256;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[type, path, assetPath, url, expectedSha256]);
}
