import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Backing notifier for the omnibox composer's current query.
///
/// Lifted out of [`AppShell`]'s local state in Wave 17 so the new
/// `/search` route can read the same buffer the bar is writing into.
class OmniboxQuery extends Notifier<String> {
  @override
  String build() => '';

  /// Setter named for explicit intent at the call site:
  /// `notifier.set('owen')` reads better than `notifier.state = 'owen'`.
  // ignore: use_setters_to_change_properties
  void set(String value) => state = value;

  void clear() => state = '';
}

/// Single source of truth for the bar's text.
///
/// **Write side**: `AppShell` (bar `onChanged` + voice dictation
/// handler) mirrors every change into here via `notifier.set(...)`.
/// The bar still owns its own `TextEditingController` for keyboard
/// behaviour; this provider is the canonical value any other
/// surface should read.
///
/// **Read side**: `OmniboxSearchScreen` renders idle / matched
/// sections based on this string. Mode (search / capture / slash)
/// is derived from the same buffer via `detectMode`.
final NotifierProvider<OmniboxQuery, String> omniboxQueryProvider =
    NotifierProvider<OmniboxQuery, String>(OmniboxQuery.new);
