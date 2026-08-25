import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';

/// One person in a [PersonFaceWrap].
class FacePerson {
  const FacePerson({required this.name, this.photoUrl, this.onTap});

  /// Display name. The label under the face is the FIRST token of it — a
  /// full name does not fit under a 40dp circle and wrapping it turns a
  /// glance into a read.
  final String name;
  final String? photoUrl;
  final VoidCallback? onTap;
}

/// A wrapped row of faces with names beneath — "who is still waiting", "who
/// is here", "who is in this group".
///
/// This exists because a comma-separated list of seven names is something you
/// *read*, and the half-second rule says a live-room surface has to be
/// something you *glance at*. Seven faces match against seven real children
/// in the room without parsing anything.
///
/// Overflow is counted, never silently dropped: past [max] the wrap ends in a
/// "+N" chip, because a list that quietly truncates reads as a complete list.
class PersonFaceWrap extends StatelessWidget {
  const PersonFaceWrap({
    required this.people,
    this.radius = 20,
    this.max = 12,
    super.key,
  });

  final List<FacePerson> people;

  /// Avatar radius. 20 (a 40dp face) is the smallest that still reads across
  /// a table; go smaller only in dense staff-facing lists.
  final double radius;

  /// How many faces to show before collapsing the rest into a count.
  final int max;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final shown = people.length > max ? people.take(max).toList() : people;
    final hidden = people.length - shown.length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final p in shown) _Face(person: p, radius: radius),
        if (hidden > 0)
          SizedBox(
            width: radius * 2,
            height: radius * 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              child: Center(
                child: Text(
                  '+$hidden',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.person, required this.radius});

  final FacePerson person;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = person.name.trim().split(RegExp(r'\s+')).first;

    final tile = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PersonAvatar(
          name: person.name,
          photoUrl: person.photoUrl,
          radius: radius,
        ),
        const SizedBox(height: 4),
        Text(
          first,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    // Sized to the face, not the name, so a long name cannot stretch the
    // cell and break the grid rhythm. The label ellipsises instead.
    final sized = SizedBox(width: radius * 2 + 12, child: tile);

    if (person.onTap == null) {
      return Semantics(label: person.name, child: sized);
    }
    return Semantics(
      label: person.name,
      button: true,
      child: InkWell(
        onTap: person.onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(padding: const EdgeInsets.all(2), child: sized),
      ),
    );
  }
}
