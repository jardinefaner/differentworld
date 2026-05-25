import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Canonical "pick a child" bottom sheet — search-as-you-type list of
/// every Subject in the signed-in viewer's space.
///
/// Returns the picked [Subject], or `null` if the user dismissed
/// without selecting. Use this from any feature that needs the user
/// to attach an action to a specific kid (promote a capture, attach
/// a photo, transfer enrollment, etc.) so the picker behaves the same
/// way everywhere.
///
/// Open it via:
///
///     final picked = await pickSubject(
///       context,
///       title: 'Whose observation is this?',
///     );
///     if (picked == null) return;
Future<Subject?> pickSubject(
  BuildContext context, {
  String title = 'Pick a child',
  String hintText = 'Search children',
}) {
  return showGlassSheet<Subject>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SubjectPickerSheet(
      title: title,
      hintText: hintText,
    ),
  );
}

class _SubjectPickerSheet extends ConsumerStatefulWidget {
  const _SubjectPickerSheet({
    required this.title,
    required this.hintText,
  });

  final String title;
  final String hintText;

  @override
  ConsumerState<_SubjectPickerSheet> createState() =>
      _SubjectPickerSheetState();
}

class _SubjectPickerSheetState
    extends ConsumerState<_SubjectPickerSheet> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjects =
        ref.watch(subjectsInSpaceProvider).value ?? const <Subject>[];
    final filtered = _filter.trim().isEmpty
        ? subjects
        : subjects.where((s) {
            final q = _filter.toLowerCase();
            return s.firstName.toLowerCase().contains(q) ||
                s.lastName.toLowerCase().contains(q);
          }).toList();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.face_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _filter = v),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          subjects.isEmpty
                              ? 'No children in your program yet.'
                              : 'No match.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final s = filtered[i];
                          final fullName = [
                            s.firstName,
                            if (s.lastName.isNotEmpty) s.lastName,
                          ].join(' ');
                          return ListTile(
                            leading: PersonAvatar(
                              name: fullName.isEmpty ? s.firstName : fullName,
                              photoUrl: s.photoUrl,
                            ),
                            title: Text(fullName),
                            onTap: () => Navigator.of(context).pop(s),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
