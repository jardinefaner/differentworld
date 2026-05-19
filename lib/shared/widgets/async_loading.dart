import 'package:flutter/material.dart';

/// The canonical "I'm loading something" body — centered spinner.
///
/// Replaces the 18+ inline `Center(child: CircularProgressIndicator())`
/// closures that screens pass as `loading: () => …` to `AsyncValue.when`.
/// Using a `const` here means Flutter can elide rebuilds on parent
/// repaints; using a named widget means a future tweak (size, padding,
/// theming) is one edit.
///
/// Named [LoadingSlot] rather than `AsyncLoading` because the latter
/// collides with Riverpod's sealed type marker on `AsyncValue`.
class LoadingSlot extends StatelessWidget {
  const LoadingSlot({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}
