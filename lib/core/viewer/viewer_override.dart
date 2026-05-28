import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dev-mode "see the app as this role would" toggle. When set, the
/// `viewerProvider` returns a synthetic `Viewer` with the chosen role's
/// default capability bundle instead of the signed-in user's real
/// caps. Lets a director walk the app as a Teacher / Substitute /
/// Kitchen / Specialist / Guardian without signing out and re-binding
/// auth.
///
/// **Safety**: gated on [kDebugMode] at the `viewerProvider` consumer
/// site — even if a release build somehow had a non-null override
/// value (it can't; this notifier has no IO that persists), the
/// `viewerProvider` would ignore it.
///
/// Reads through the real viewer's `member` row (display name, photo,
/// space id) so identity-bearing surfaces still feel coherent. Only
/// role + capabilities are overridden.
final viewerKindOverrideProvider =
    NotifierProvider<ViewerKindOverrideNotifier, String?>(
  ViewerKindOverrideNotifier.new,
);

class ViewerKindOverrideNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  /// Pass a `RoleKey.*` string (director / leadTeacher / teacher / …),
  /// `'guardian'`, or null to clear the override and snap back to the
  /// signed-in identity.
  // ignore: use_setters_to_change_properties
  void set(String? roleKey) => state = roleKey;

  void clear() => state = null;
}

/// Builds a synthetic [Viewer] that reports [overrideRoleKey] as the
/// role and the role's default capability bundle as the caps. The
/// real `member.id`, `displayName`, photo, and `spaceId` flow through
/// unchanged so chrome that says "Hi {name}" stays right.
///
/// Returns null when [base] has no member (signed out / pre-sync) —
/// no real identity to wrap, nothing to override.
Viewer? buildOverrideViewer(Viewer base, String overrideRoleKey) {
  final realMember = base.member;
  if (realMember == null) return null;
  // Synthesize a member copy with the override role + the role's
  // default cap bundle. Drift's data classes are immutable, so we use
  // copyWith.
  final overrideCaps =
      Capabilities(RoleBundles.defaultsFor(overrideRoleKey));
  final synthesized = realMember.copyWith(
    role: overrideRoleKey,
    capabilities: overrideCaps.toJson(),
  );
  return Viewer(member: synthesized, space: base.space);
}
