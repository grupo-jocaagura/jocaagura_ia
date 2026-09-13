import 'domain_values.dart';

// Shared pure content helpers. Never resolve resources or expose input payloads.
T requiredUpdate<T>(Object? value, T current) {
  if (identical(value, unset)) {
    return current;
  }
  if (value is T) {
    return value;
  }
  throw ArgumentError('Replacement must have the required field type');
}

T decodeAt<T>(String path, T Function() decode) {
  try {
    return decode();
  } on FormatException catch (error) {
    throw FormatException('$path: ${error.message}');
  } on ArgumentError catch (error) {
    throw FormatException('$path: ${error.message}');
  }
}

T readContentEnum<T extends Enum>(Object? value, List<T> values) {
  for (final T candidate in values) {
    if (candidate.name == value) {
      return candidate;
    }
  }
  throw const FormatException('Unknown or invalid enum value');
}

List<T> readContentList<T>(Object? value, T Function(Object?) decode) {
  final List<Object?> items = readList(value, 'value');
  return <T>[
    for (int index = 0; index < items.length; index++)
      decodeAt('[$index]', () => decode(items[index])),
  ];
}

void forbidKeys(Map<String, dynamic> json, List<String> keys) {
  for (final String key in keys) {
    if (json.containsKey(key)) {
      throw FormatException('$key: field is forbidden for this variant');
    }
  }
}

String normalizeImageMime(String value) {
  final String normalized = String.fromCharCodes(
    value.codeUnits.map(
      (int unit) => unit >= 65 && unit <= 90 ? unit + 32 : unit,
    ),
  );
  final RegExp grammar = RegExp(r'^image/[a-z0-9][a-z0-9!#$&^_.+-]*$');
  final RegExpMatch? match = grammar.firstMatch(normalized);
  if (match == null || match.end != normalized.length) {
    throw ArgumentError('mimeType: invalid image MIME syntax');
  }
  return normalized;
}

Map<String, String> freezeMetadata(Map<String, String> value) {
  for (final String key in value.keys) {
    if (key.trim().isEmpty) {
      throw ArgumentError('metadata: keys must be nonblank');
    }
  }
  return Map<String, String>.unmodifiable(value);
}

Map<String, String> readMetadata(Map<String, dynamic> json) =>
    decodeAt('metadata', () {
      if (!json.containsKey('metadata')) {
        return <String, String>{};
      }
      final Map<String, dynamic> values = readObject(json['metadata'], 'value');
      return freezeMetadata(<String, String>{
        for (final MapEntry<String, dynamic> entry in values.entries)
          entry.key: readString(entry.value, 'value'),
      });
    });

Map<String, String> metadataJson(Map<String, String> value) => <String, String>{
  for (final String key in value.keys.toList()..sort()) key: value[key]!,
};

bool metadataEquals(Map<String, String> a, Map<String, String> b) =>
    a.length == b.length &&
    a.entries.every(
      (MapEntry<String, String> entry) => b[entry.key] == entry.value,
    );

int metadataHash(Map<String, String> value) => Object.hashAllUnordered(
  value.entries.map(
    (MapEntry<String, String> entry) => Object.hash(entry.key, entry.value),
  ),
);
