import 'package:differentworld/core/viewer/viewer.dart';

/// Ergonomic guards on [Viewer] for action-providers.
///
/// Every `XxxActions` class used to open with the same boilerplate:
///
///     final viewer = _ref.read(viewerProvider);
///     final spaceId = viewer.spaceId;
///     if (spaceId == null) {
///       throw StateError('No Space — cannot save a survey response.');
///     }
///
/// …with each provider rolling its own slightly-different error
/// message. The action-message is decoration; what matters is that
/// the precondition exists. Replace the block with:
///
///     final spaceId = ref.read(viewerProvider).requireSpaceId();
///
/// The error message is uniform across the app, so when one lands
/// in the crash logs the operator immediately knows what happened.
/// If you need a contextual message, pass `action`:
///
///     final spaceId = viewer.requireSpaceId(action: 'save a capture');
extension ViewerRequireX on Viewer {
  /// Returns the viewer's space id, or throws [StateError] when there's
  /// no space. The caller doesn't have to null-check the result.
  String requireSpaceId({String? action}) {
    final id = spaceId;
    if (id == null) {
      throw StateError(_msg('No Space', action));
    }
    return id;
  }

  /// Returns the viewer's member id, or throws [StateError] when the
  /// viewer is unauthenticated or has no member row yet (mid-sync
  /// after sign-in).
  String requireMemberId({String? action}) {
    final id = memberId;
    if (id == null) {
      throw StateError(_msg('No signed-in Member', action));
    }
    return id;
  }

  /// Asserts both space and member presence at once. Useful when a
  /// mutation needs both — most do.
  ({String spaceId, String memberId}) requireSpaceAndMember({
    String? action,
  }) => (
    spaceId: requireSpaceId(action: action),
    memberId: requireMemberId(action: action),
  );
}

String _msg(String what, String? action) =>
    action == null ? '$what.' : '$what — cannot $action.';
