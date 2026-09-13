// Final fields and defensive copies keep these SDK-only values immutable.
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'dart:convert';

import '../enums/ai_enums.dart';
import '../internal/content_values.dart';
import '../internal/domain_values.dart';

/// Input content location, separate from model artifact acquisition.
sealed class ModelAiContentSource {
  const ModelAiContentSource();

  /// Decodes a source without opening a file or interpreting image bytes.
  factory ModelAiContentSource.fromJson(Map<String, dynamic> json) {
    final EnumAiContentSourceType type = decodeAt(
      'type',
      () => readContentEnum(json['type'], EnumAiContentSourceType.values),
    );
    return switch (type) {
      EnumAiContentSourceType.inlineBytes => ModelAiInlineBytesSource.fromJson(
        json,
      ),
      EnumAiContentSourceType.localFile => ModelAiLocalFileSource.fromJson(
        json,
      ),
    };
  }

  EnumAiContentSourceType get type;
  Map<String, dynamic> toJson();
}

/// Immutable image payload bytes; their format is not decoded or certified.
final class ModelAiInlineBytesSource extends ModelAiContentSource {
  ModelAiInlineBytesSource({required List<int> bytes})
    : bytes = List<int>.unmodifiable(bytes) {
    if (this.bytes.isEmpty ||
        this.bytes.any((int byte) => byte < 0 || byte > 255)) {
      throw ArgumentError('bytes: expected nonempty integers 0..255');
    }
  }

  factory ModelAiInlineBytesSource.fromJson(Map<String, dynamic> json) {
    decodeAt('type', () {
      if (json['type'] != 'inlineBytes') {
        throw const FormatException('Expected inlineBytes');
      }
    });
    forbidKeys(json, <String>['path']);
    return decodeAt('bytesBase64', () {
      final String encoded = readString(json['bytesBase64'], 'value');
      final List<int> decoded;
      try {
        decoded = base64Decode(encoded);
      } on FormatException {
        // SDK decoder errors may contain the raw data; never forward those.
        throw const FormatException('Invalid canonical Base64');
      }
      if (base64Encode(decoded) != encoded) {
        throw const FormatException('Invalid canonical Base64');
      }
      return ModelAiInlineBytesSource(bytes: decoded);
    });
  }

  /// A copied, unmodifiable sequence, not a shared typed-data buffer.
  final List<int> bytes;
  @override
  EnumAiContentSourceType get type => EnumAiContentSourceType.inlineBytes;
  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type.name,
    'bytesBase64': base64Encode(bytes),
  };
  ModelAiInlineBytesSource copyWith({Object? bytes = unset}) =>
      ModelAiInlineBytesSource(bytes: requiredUpdate(bytes, this.bytes));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelAiInlineBytesSource && listEquals(bytes, other.bytes);
  @override
  int get hashCode => Object.hash(type, Object.hashAll(bytes));
}

/// A lexical local-file reference, never an access grant or locality proof.
final class ModelAiLocalFileSource extends ModelAiContentSource {
  ModelAiLocalFileSource({required this.path}) {
    final String lower = path.toLowerCase();
    if (path.trim().isEmpty ||
        path.contains('\u0000') ||
        path.contains('://') ||
        lower.startsWith('data:') ||
        lower.startsWith('file:') ||
        path.startsWith('//') ||
        path.startsWith(r'\\')) {
      throw ArgumentError('path: expected a nonblank local-file reference');
    }
  }
  factory ModelAiLocalFileSource.fromJson(Map<String, dynamic> json) {
    decodeAt('type', () {
      if (json['type'] != 'localFile') {
        throw const FormatException('Expected localFile');
      }
    });
    forbidKeys(json, <String>['bytesBase64']);
    return decodeAt(
      'path',
      () => ModelAiLocalFileSource(path: readString(json['path'], 'value')),
    );
  }

  /// Preserved exactly; no filesystem inspection or path normalization.
  final String path;
  @override
  EnumAiContentSourceType get type => EnumAiContentSourceType.localFile;
  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type.name,
    'path': path,
  };
  ModelAiLocalFileSource copyWith({Object? path = unset}) =>
      ModelAiLocalFileSource(path: requiredUpdate(path, this.path));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelAiLocalFileSource && path == other.path;
  @override
  int get hashCode => Object.hash(type, path);
}
