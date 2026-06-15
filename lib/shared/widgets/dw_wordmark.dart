import 'package:differentworld/app/design_tokens.dart';
import 'package:flutter/material.dart';

/// The canonical **Different World** wordmark — the brand's hero voice made a
/// widget, so login, onboarding, and exported artifacts all speak it
/// identically and the wordmark is never hand-set again.
///
/// The treatment is the one [AppType] defines for hero moments: the geometric
/// **Jost** display face, **thin** (w300), **uppercased**, and **wide-tracked**
/// — the hierarchy lives in weight + case + air, not in mixing fonts. WORLD
/// steps up one weight (w400) so the two words read as a pair, not a repeat.
///
/// Reach for this anywhere the brand name appears at size — the login hero,
/// the onboarding open, an exported report's masthead. Small inline mentions
/// in body copy stay as plain `Text`.
class DwWordmark extends StatelessWidget {
  const DwWordmark({
    this.size = 34,
    this.color,
    this.stacked = true,
    this.tagline,
    super.key,
  });

  /// Cap height of the wordmark in logical pixels. Tracking scales with it.
  final double size;

  /// Override the ink. Defaults to the scheme's `onSurface` so it follows
  /// dark/light; pass a brand colour (or white) for a coloured hero panel.
  final Color? color;

  /// `DIFFERENT` / `WORLD` on two centered lines (the default hero lockup)
  /// vs a single inline line (tight headers, exports).
  final bool stacked;

  /// Optional eyebrow under the mark, rendered in the small tracked-caps
  /// label voice (e.g. "imagination, first"). Uppercased here.
  final String? tagline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = color ?? theme.colorScheme.onSurface;
    // Wide tracking that scales with the type size — the hero voice is airy.
    final base = TextStyle(
      fontFamily: AppType.display,
      fontWeight: FontWeight.w300,
      fontSize: size,
      height: 1.14,
      letterSpacing: size * 0.3,
      color: ink,
    );

    final mark = stacked
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('DIFFERENT', style: base, textAlign: TextAlign.center),
              Text(
                'WORLD',
                style: base.copyWith(fontWeight: FontWeight.w400),
                textAlign: TextAlign.center,
              ),
            ],
          )
        : Text('DIFFERENT WORLD', style: base, textAlign: TextAlign.center);

    final body = tagline == null
        ? mark
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              mark,
              SizedBox(height: size * 0.42),
              Text(
                tagline!.toUpperCase(),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: AppType.tracking + 1,
                ),
              ),
            ],
          );

    // The tracked, line-split caps would read letter-by-letter to a screen
    // reader; announce the brand name as one phrase instead.
    return Semantics(
      label: tagline == null ? 'Different World' : 'Different World. $tagline',
      excludeSemantics: true,
      child: body,
    );
  }
}
