import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';

/// Standard "you don't have permission to see this" placeholder.
///
/// Used as a screen-level guard inside protected routes so deep links
/// + stale cap state can't bypass UI gating. Renders an EmptyState
/// with a lock icon and copy that points the user back home.
class NoAccess extends StatelessWidget {
  const NoAccess({
    this.title = "You don't have access to this.",
    this.message =
        "Your role doesn't include this action. Ask your director if "
        'this should change.',
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.lock_outline,
      title: title,
      message: message,
    );
  }
}
