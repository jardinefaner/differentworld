import 'package:differentworld/features/speak/speak_history.dart';
import 'package:differentworld/features/speak/speak_presentation.dart';
import 'package:differentworld/features/speak/speak_voices.dart';
import 'package:differentworld/features/speak/type_theme.dart';
import 'package:differentworld/shared/format/relative_time.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:flutter/material.dart';

/// Pick which voice reads it. A pre-speak choice (a different voice is
/// different audio, so it re-synthesizes) — the type toggle, by contrast,
/// stays live during the performance.
class VoiceSelector extends StatelessWidget {
  const VoiceSelector({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final SpeakVoice selected;
  final ValueChanged<SpeakVoice> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Voice',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in speakVoices)
              _VoiceTile(
                voice: v,
                selected: v.id == selected.id,
                onTap: () => onChanged(v),
              ),
          ],
        ),
      ],
    );
  }
}

class _VoiceTile extends StatelessWidget {
  const _VoiceTile({
    required this.voice,
    required this.selected,
    required this.onTap,
  });

  final SpeakVoice voice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final desc = voice.descriptor;
    return Semantics(
      button: true,
      selected: selected,
      label: '${voice.label} voice${desc == null ? '' : ', $desc'}',
      child: Material(
        color: selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: selected
              ? BorderSide(color: scheme.primary, width: 1.5)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            // ≥48dp tap target (audit E1: ChoiceChip was ~32dp).
            constraints: const BoxConstraints(minHeight: 48, minWidth: 68),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The voice's colour identity, previewed.
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: voice.palette.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voice.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurface,
                        ),
                      ),
                      if (desc != null)
                        Text(
                          desc,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                (selected
                                        ? scheme.onPrimaryContainer
                                        : scheme.onSurfaceVariant)
                                    .withValues(alpha: 0.85),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two pills — each rendered IN its own face, so the choice is a live preview.
class TypeSelector extends StatelessWidget {
  const TypeSelector({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final SpeakType selected;
  final ValueChanged<SpeakType> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          'Type',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 14),
        for (final t in SpeakType.values) ...[
          _TypePill(
            type: t,
            selected: t == selected,
            onTap: () => onChanged(t),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final SpeakType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '${type.label} type',
      child: Material(
        color: selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        shape: StadiumBorder(
          side: selected
              ? BorderSide(color: scheme.primary, width: 1.5)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            // ≥48dp tap target.
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            child: Text(
              type.label,
              style: TextStyle(
                fontFamily: type.family,
                fontSize: 19,
                color: selected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
                fontVariations: type.axesAt(selected ? 620 : 460),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pick the presentation mode. Changeable live in performance too — every
/// mode reads the same timeline, so switching is just a different look.
class ModeSelector extends StatelessWidget {
  const ModeSelector({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final SpeakPresentation selected;
  final ValueChanged<SpeakPresentation> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Show',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in implementedSpeakModes)
              _ModeChip(
                mode: m,
                selected: m == selected,
                onTap: () => onChanged(m),
              ),
          ],
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final SpeakPresentation mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '${mode.label} mode',
      child: Material(
        color: selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: selected
              ? BorderSide(color: scheme.primary, width: 1.5)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    mode.icon,
                    size: 18,
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    mode.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Recent pieces — tap any to replay it INSTANTLY (loads the stored script +
/// cached audio: no re-synthesis, no ElevenLabs). Also the "go back to where I
/// was": it persists across navigation.
class RecentList extends StatelessWidget {
  const RecentList({
    required this.entries,
    required this.onTap,
    required this.onClear,
    super.key,
  });

  final List<SpeakHistoryEntry> entries;
  final void Function(SpeakHistoryEntry) onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Recent',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            TextButton(onPressed: onClear, child: const Text('Clear')),
          ],
        ),
        const SizedBox(height: 4),
        for (final e in entries.take(8))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RecentItem(entry: e, onTap: () => onTap(e)),
          ),
      ],
    );
  }
}

class _RecentItem extends StatelessWidget {
  const _RecentItem({required this.entry, required this.onTap});

  final SpeakHistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final voice = speakVoices.firstWhere(
      (v) => v.id == entry.voiceId,
      orElse: () => speakVoices.first,
    );
    final snippet = entry.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    final when = relativeTimeAgo(
      DateTime.fromMillisecondsSinceEpoch(entry.createdAtMs),
    );
    return FeatureCard(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: voice.palette.accent.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.play_arrow_rounded, color: voice.palette.accent),
      ),
      title: snippet,
      subtitle: '${voice.label} · $when',
      onTap: onTap,
    );
  }
}

/// Discloses that the typed text leaves the device for a voice service —
/// and nudges staff away from pasting child PII (audit XC-3).
class PrivacyNote extends StatelessWidget {
  const PrivacyNote({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Your text is sent to a voice service to create the audio — keep '
            "children's names and personal details out of it.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class ErrorNote extends StatelessWidget {
  const ErrorNote({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // liveRegion: assistive tech announces the failure when it appears, without
    // the user having to refocus. The "Speak it" button stays enabled, so
    // retry is just tapping again — no separate retry affordance needed.
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
