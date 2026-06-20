import 'package:flutter_riverpod/flutter_riverpod.dart';

/// When true, AppShell drops the bottom omnibox-bar **content reservation** so
/// the active route fills UNDER the (transparent) bar — the route's own
/// background then reaches the true bottom of the screen instead of leaving the
/// dark Scaffold surface showing as a strip behind the bar.
///
/// The omnibox bar still renders; only the route content's bottom padding is
/// removed. Opt in ONLY from a route whose bottom region is **non-interactive**
/// (e.g. the cockpit's centred beat), so nothing tappable hides under the bar.
///
/// The opting route sets it on mount and clears it on dispose; navigating to
/// another shell route disposes that route's State, which restores the
/// reservation for the next screen.
class FillUnderOmnibox extends Notifier<bool> {
  @override
  bool build() => false;

  void enter() => state = true;
  void exit() => state = false;
}

final fillUnderOmniboxProvider = NotifierProvider<FillUnderOmnibox, bool>(
  FillUnderOmnibox.new,
);
