import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/photos/photo_consent.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The program's declared posture for children nobody has answered for yet
/// (docs/CONSENT.md).
///
/// Extracted because the same six-line `viewer.space?.caps.getBool(...) ??
/// true` was being re-derived at every consent-checking call site, and a
/// consent default that is spelled out by hand in five places is a consent
/// default that will eventually disagree with itself.
///
/// It can only decide the UNKNOWN case. A family's recorded "no" is never
/// overridden — that logic lives in [photosAllowedFor] and stays there.
// ignore: specify_nonobvious_property_types
final spaceDefaultAllowsPhotosProvider = Provider.autoDispose<bool>((ref) {
  return ref
          .watch(viewerProvider)
          .space
          ?.caps
          .getBool(SpaceCaps.photoDefaultConsent, fallback: true) ??
      true;
});

/// [subject]'s photo URL, or null when it may not be shown.
///
/// Use this anywhere a child's face is rendered — a roster row, the picker,
/// a cast screen. Consent covers being *shown*, not only being taken, so a
/// declining family's child falls back to initials rather than appearing on
/// a screen pointed at the room.
String? consentedPhotoUrl(Subject subject, {required bool defaultAllows}) {
  return photosAllowedFor(subject, spaceDefaultAllows: defaultAllows)
      ? subject.photoUrl
      : null;
}
