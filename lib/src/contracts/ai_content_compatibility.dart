import '../enums/ai_enums.dart';
import '../models/model_ai_content_capabilities.dart';
import '../models/model_ai_content_compatibility.dart';
import '../models/model_ai_content_part.dart';
import '../models/model_ai_content_source.dart';
import '../models/model_ai_message.dart';
import '../models/model_ai_request.dart';

/// Checks both declarations without IO, image decoding or runtime lookup.
///
/// Missing profiles/allowlists mean unknown support. Null maxima impose no
/// declared bound; they never imply unlimited resources. A known denial wins
/// over unknown checks. Even a matching report is not execution certification.
ModelAiContentCompatibility assessAiContentCompatibility({
  required ModelAiRequest request,
  ModelAiContentCapabilities? modelCapabilities,
  ModelAiContentCapabilities? backendCapabilities,
}) {
  final _Assessment assessment = _Assessment(request);
  assessment.check('model profile', modelCapabilities);
  assessment.check('backend profile', backendCapabilities);
  return ModelAiContentCompatibility(
    status: assessment.unsupported
        ? EnumAiContentCompatibilityStatus.unsupported
        : assessment.reasons.isNotEmpty
        ? EnumAiContentCompatibilityStatus.undetermined
        : EnumAiContentCompatibilityStatus.meetsDeclaredConstraints,
    reasons: assessment.reasons,
  );
}

class _Assessment {
  _Assessment(this.request);
  final ModelAiRequest request;
  final List<String> reasons = <String>[];
  bool unsupported = false;

  void reject(String reason) {
    unsupported = true;
    reasons.add(reason);
  }

  void allow<T>(Set<T>? allowed, T value, String path) {
    if (allowed == null) {
      reasons.add('$path: allowlist is unknown');
    } else if (!allowed.contains(value)) {
      reject('$path: not declared as supported');
    }
  }

  void limit(int? maximum, int actual, String path) {
    if (maximum != null && actual > maximum) {
      reject('$path: declared maximum exceeded');
    }
  }

  void check(String label, ModelAiContentCapabilities? profile) {
    if (profile == null) {
      reasons.add('$label: content capabilities are unknown');
      return;
    }
    final List<({String path, ModelAiImagePart image})> images =
        <({String path, ModelAiImagePart image})>[];
    for (int m = 0; m < request.messages.length; m++) {
      final ModelAiMessage message = request.messages[m];
      for (int p = 0; p < message.parts.length; p++) {
        final ModelAiContentPart part = message.parts[p];
        final String path = 'messages[$m].parts[$p]';
        allow(
          profile.inputModalities,
          part.type,
          '$label.inputModalities: $path.type',
        );
        if (part is ModelAiImagePart) {
          images.add((path: path, image: part));
        }
      }
    }
    allow(
      profile.outputModalities,
      EnumAiOutputModality.text,
      '$label.outputModalities',
    );
    for (int m = 0; m < request.messages.length; m++) {
      allow(
        profile.inputRoles,
        request.messages[m].role,
        '$label.inputRoles: messages[$m].role',
      );
    }
    // Do not report unknown image fields on a profile that already denies images.
    if (profile.inputModalities.contains(EnumAiInputModality.image)) {
      for (final ({String path, ModelAiImagePart image}) item in images) {
        allow(
          profile.imageSourceTypes,
          item.image.source.type,
          '$label.imageSourceTypes: ${item.path}.source.type',
        );
      }
      for (final ({String path, ModelAiImagePart image}) item in images) {
        allow(
          profile.imageMimeTypes,
          item.image.mimeType,
          '$label.imageMimeTypes: ${item.path}.mimeType',
        );
      }
    }
    limit(
      profile.maxMessagesPerRequest,
      request.messages.length,
      '$label.maxMessagesPerRequest',
    );
    limit(
      profile.maxImagesPerRequest,
      images.length,
      '$label.maxImagesPerRequest',
    );
    final int? maxBytes = profile.maxBytesPerImage;
    if (maxBytes != null) {
      for (final ({String path, ModelAiImagePart image}) item in images) {
        final String path = '$label.maxBytesPerImage: ${item.path}.source';
        switch (item.image.source) {
          case ModelAiInlineBytesSource(:final List<int> bytes):
            limit(maxBytes, bytes.length, path);
          case ModelAiLocalFileSource():
            reasons.add('$path: byte size requires IO');
        }
      }
    }
  }
}
