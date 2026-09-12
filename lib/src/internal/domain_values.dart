// Internal validation and value helpers; not part of the public package API.
const Object unset = Object();

T? nullableUpdate<T>(Object? value, T? current) {
  if (identical(value, unset)) {
    return current;
  }
  if (value == null) {
    return null;
  }
  if (value is T) {
    return value as T;
  }
  throw ArgumentError.value(value, 'value', 'Unexpected replacement type');
}

void requireText(String value, String field, {bool allowWhitespace = false}) {
  if (allowWhitespace ? value.isEmpty : value.trim().isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty');
  }
}

void requireCount(int? value, String field, {bool positive = false}) {
  if (value != null && (positive ? value <= 0 : value < 0)) {
    throw ArgumentError.value(
      value,
      field,
      'Outside the allowed integer range',
    );
  }
}

void requireReal(double? value, String field, {double? maximum}) {
  if (value != null &&
      (!value.isFinite || value < 0 || (maximum != null && value > maximum))) {
    throw ArgumentError.value(value, field, 'Outside the allowed finite range');
  }
}

T decodeModel<T>(T Function() build) {
  try {
    return build();
  } on ArgumentError catch (error) {
    throw FormatException(error.message.toString());
  }
}

String readString(Object? value, String field) {
  if (value is String) {
    return value;
  }
  throw FormatException('$field must be a string');
}

String? readOptionalString(Object? value, String field) =>
    value == null ? null : readString(value, field);

int? readOptionalInt(Object? value, String field) {
  if (value == null || value is int) {
    return value as int?;
  }
  throw FormatException('$field must be an integer or null');
}

double? readOptionalDouble(Object? value, String field) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('$field must be a number or null');
}

bool readBool(Object? value, String field) {
  if (value is bool) {
    return value;
  }
  throw FormatException('$field must be a boolean');
}

Map<String, dynamic> readObject(Object? value, String field) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  throw FormatException('$field must be a JSON object');
}

List<Object?> readList(Object? value, String field) {
  if (value is List<Object?>) {
    return value;
  }
  throw FormatException('$field must be a JSON array');
}

T readEnum<T extends Enum>(Object? value, List<T> values, String field) {
  for (final T candidate in values) {
    if (candidate.name == value) {
      return candidate;
    }
  }
  throw FormatException('Unknown $field: $value');
}

bool listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) {
    return false;
  }
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

bool setEquals<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);
