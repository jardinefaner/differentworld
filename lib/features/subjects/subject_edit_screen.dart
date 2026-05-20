import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/guardians/guardians_providers.dart';
import 'package:differentworld/features/invites/invites_providers.dart';
import 'package:differentworld/features/invites/widgets/invite_share_sheet.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/features/photos/widgets/photo_source_sheet.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/dismiss_guard.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Full-screen "Edit student" / "New student" — promoted from the
/// former SubjectFormSheet because settings buried in modal sheets
/// were hard to discover. Guardian add is also inline here (no nested
/// sheet) so users keep a single back-button context throughout.
///
/// Routes:
/// - `/groups/:gid/students/new` — create (subjectId is null)
/// - `/groups/:gid/students/:sid/edit` — edit (loads subject by id)
class SubjectEditScreen extends ConsumerStatefulWidget {
  const SubjectEditScreen({
    required this.groupId,
    this.subjectId,
    super.key,
  });

  final String groupId;
  final String? subjectId;

  bool get isEdit => subjectId != null;

  @override
  ConsumerState<SubjectEditScreen> createState() => _SubjectEditScreenState();
}

class _SubjectEditScreenState extends ConsumerState<SubjectEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _allergies;
  late final TextEditingController _notes;
  DateTime? _dob;

  bool _saving = false;
  String? _error;
  bool _seeded = false; // controllers populated from stream on first build

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController();
    _lastName = TextEditingController();
    _allergies = TextEditingController();
    _notes = TextEditingController();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _allergies.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Seed the controllers once from the live subject row (edit mode).
  /// For new-student mode there's nothing to seed.
  void _seedFromSubject(Subject? s) {
    if (_seeded || s == null) return;
    _firstName.text = s.firstName;
    _lastName.text = s.lastName;
    _allergies.text = s.allergies ?? '';
    _notes.text = s.notes ?? '';
    final dobIso = s.dob;
    _dob = dobIso == null ? null : DateTime.tryParse(dobIso);
    _seeded = true;
  }

  bool _isDirty(Subject? s) {
    final dobIso = _dob == null
        ? null
        : '${_dob!.year.toString().padLeft(4, '0')}-'
            '${_dob!.month.toString().padLeft(2, '0')}-'
            '${_dob!.day.toString().padLeft(2, '0')}';
    if (s == null) {
      return _firstName.text.trim().isNotEmpty ||
          _lastName.text.trim().isNotEmpty ||
          _allergies.text.trim().isNotEmpty ||
          _notes.text.trim().isNotEmpty ||
          _dob != null;
    }
    return _firstName.text.trim() != s.firstName ||
        _lastName.text.trim() != s.lastName ||
        _allergies.text.trim() != (s.allergies ?? '') ||
        _notes.text.trim() != (s.notes ?? '') ||
        dobIso != s.dob;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 3, now.month, now.day),
      firstDate: DateTime(now.year - 12),
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() => _dob = picked);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final actions = ref.read(subjectActionsProvider);
    final dob = _dob?.toIso8601String().substring(0, 10);
    final allergiesText = _allergies.text.trim();
    final notesText = _notes.text.trim();
    final allergies = allergiesText.isEmpty ? null : allergiesText;
    final notes = notesText.isEmpty ? null : notesText;

    final ok = await runReported(
      library: 'subjects',
      action: () => widget.isEdit
          ? actions.update(
              id: widget.subjectId!,
              firstName: _firstName.text.trim(),
              lastName: _lastName.text.trim(),
              dob: dob,
              allergies: allergies,
              notes: notes,
            )
          : actions.create(
              groupId: widget.groupId,
              firstName: _firstName.text.trim(),
              lastName: _lastName.text.trim(),
              dob: dob,
              allergies: allergies,
              notes: notes,
            ),
    );
    if (!mounted) return;
    if (ok) {
      context.pop();
      return;
    }
    setState(() {
      _saving = false;
      _error = 'Could not save. Please try again.';
    });
  }

  Future<void> _delete() async {
    if (!ref.read(viewerProvider).canManageProgram) return;
    if (!widget.isEdit) return;
    final s = ref.read(subjectByIdProvider(widget.subjectId!)).value;
    if (s == null) return;
    final confirmed = await confirmDestructive(
      context,
      title: 'Remove this student?',
      message:
          'Removing ${s.firstName} ${s.lastName} hides them from '
          'attendance and the classroom roster. Their history stays '
          'in your records.',
      confirmLabel: 'Remove student',
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    final ok = await runReported(
      library: 'subjects',
      action: () => ref.read(subjectActionsProvider).delete(s.id),
    );
    if (!mounted) return;
    if (ok) {
      // Pop twice: this edit screen + the subject detail beneath it
      // would otherwise still point at the now-deleted row.
      context.pop();
      if (!mounted) return;
      // Some callers reach edit from the classroom roster (no detail
      // beneath); pop only if the navigator still has somewhere to go.
      if (context.canPop()) context.pop();
      return;
    }
    setState(() {
      _saving = false;
      _error = 'Could not remove. Please try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjectAsync = widget.isEdit
        ? ref.watch(subjectByIdProvider(widget.subjectId!))
        : const AsyncValue<Subject?>.data(null);
    // Seed controllers as soon as the edit-target row arrives, then
    // pluck the value off for the dirty check.
    final subjectForDirtyCheck =
        (subjectAsync..whenData(_seedFromSubject)).value;

    return DismissGuard(
      isDirty: () => _isDirty(subjectForDirtyCheck),
      child: EdgeScaffold(
        backFallbackRoute: widget.isEdit
            ? '/groups/${widget.groupId}/students/${widget.subjectId}'
            : '/groups/${widget.groupId}',
        actions: [
          IconButton(
            tooltip: 'Save',
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
          ),
        ],
        body: subjectAsync.when(
          loading: () => const LoadingSlot(),
          error: (_, _) =>
              const Center(child: Text('Could not load student.')),
          data: (subject) {
            // Edit mode but row missing: subject was deleted out from
            // under us (sync). Show empty rather than a half-bound form.
            if (widget.isEdit && subject == null) {
              return const Center(child: Text('Student not found.'));
            }
            // The form key + controllers persist across tab switches —
            // wrapping the TabBarView in a single Form means validation
            // runs across every tab on save (no "field on another tab
            // missing required value" surprises).
            final canRemove = widget.isEdit &&
                ref.watch(viewerProvider).canManageProgram;
            return Form(
              key: _formKey,
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    const SizedBox(height: 56),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ContentHeader(
                        title: widget.isEdit ? 'Edit student' : 'New student',
                        subtitle: widget.isEdit
                            ? null
                            : "Add to this classroom's roster",
                        topGap: 0,
                        bottomGap: 8,
                      ),
                    ),
                    const TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      tabs: [
                        Tab(text: 'Basics'),
                        Tab(text: 'Family'),
                        Tab(text: 'Alerts & notes'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // -- Tab 1: Basics ---------------------------
                          ListView(
                            padding:
                                const EdgeInsets.fromLTRB(16, 16, 16, 32),
                            children: [
                              if (widget.isEdit && subject != null) ...[
                                Center(
                                  child: PersonAvatar(
                                    name: '${_firstName.text} '
                                        '${_lastName.text}',
                                    photoUrl: subject.photoUrl,
                                    radius: 48,
                                    onTap: () => PhotoSourceSheet.show(
                                      context,
                                      entity: PhotoEntity.subject,
                                      entityId: subject.id,
                                      hasExisting:
                                          subject.photoUrl != null,
                                      displayName:
                                          '${subject.firstName} '
                                          '${subject.lastName}',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _firstName,
                                      autofocus: !widget.isEdit,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      textInputAction:
                                          TextInputAction.next,
                                      decoration: const InputDecoration(
                                        labelText: 'First name',
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                              ? 'Required'
                                              : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _lastName,
                                      textCapitalization:
                                          TextCapitalization.words,
                                      textInputAction:
                                          TextInputAction.next,
                                      decoration: const InputDecoration(
                                        labelText: 'Last name',
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                              ? 'Required'
                                              : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: _pickDob,
                                borderRadius: BorderRadius.circular(4),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Date of birth (optional)',
                                    border: OutlineInputBorder(),
                                    suffixIcon: Icon(
                                      Icons.calendar_today_outlined,
                                    ),
                                  ),
                                  child: Text(
                                    _dob == null
                                        ? 'Tap to choose'
                                        : _formatDob(_dob!),
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          // -- Tab 2: Family ---------------------------
                          ListView(
                            padding:
                                const EdgeInsets.fromLTRB(16, 16, 16, 32),
                            children: [
                              if (widget.isEdit && subject != null)
                                _GuardiansSection(subjectId: subject.id)
                              else
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text(
                                    'Save the basics first, then add '
                                    'guardians here.',
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                      color: theme
                                          .colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // -- Tab 3: Alerts & notes -------------------
                          ListView(
                            padding:
                                const EdgeInsets.fromLTRB(16, 16, 16, 32),
                            children: [
                              TextFormField(
                                controller: _allergies,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Allergies (optional)',
                                  hintText: 'e.g. Peanuts, dairy',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _notes,
                                minLines: 4,
                                maxLines: 10,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: const InputDecoration(
                                  labelText: 'Notes (optional)',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              if (canRemove) ...[
                                const SizedBox(height: 24),
                                const Divider(),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: DestructiveButton(
                                    label: 'Remove student',
                                    icon: Icons
                                        .person_remove_alt_1_outlined,
                                    onPressed:
                                        _saving ? null : _delete,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static String _formatDob(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

Future<void> _sendGuardianInvite(
  BuildContext context,
  WidgetRef ref,
  Guardian g,
) async {
  final viewer = ref.read(viewerProvider);
  final spaceId = viewer.spaceId;
  if (spaceId == null) return;
  // Capture messenger BEFORE the first await — the lint flags us
  // for reading context-derived state after async gaps otherwise.
  final messenger = ScaffoldMessenger.maybeOf(context);
  final db = await ref.read(appDatabaseProvider.future);
  final sg = await (db.select(db.subjectGuardians)
        ..where((row) => row.guardianId.equals(g.id))
        ..limit(1))
      .getSingleOrNull();
  if (sg == null) return;

  Invite? created;
  final ok = await runReported(
    library: 'guardians',
    messenger: messenger,
    onError: 'Could not create invite. Try again.',
    action: () async {
      created = await ref.read(inviteActionsProvider).createGuardianInvite(
            spaceId: spaceId,
            subjectId: sg.subjectId,
            expiry: InviteExpiry.thirtyDays,
            email: g.email,
            createdBy: viewer.memberId,
          );
    },
  );
  if (!ok || created == null || !context.mounted) return;
  await InviteShareSheet.show(context, invite: created!);
}

/// Inline guardians editor — lists existing guardians and offers an
/// expand-in-place "Add guardian" form. Was previously a separate
/// modal sheet that nested under the edit-subject sheet, which made
/// the screen feel two layers deep with no breadcrumb. Now it's a
/// regular section the user can see and reach without leaving context.
class _GuardiansSection extends ConsumerStatefulWidget {
  const _GuardiansSection({required this.subjectId});

  final String subjectId;

  @override
  ConsumerState<_GuardiansSection> createState() =>
      _GuardiansSectionState();
}

class _GuardiansSectionState extends ConsumerState<_GuardiansSection> {
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final guardiansAsync =
        ref.watch(guardiansForSubjectProvider(widget.subjectId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Family', style: theme.textTheme.titleSmall),
            const Spacer(),
            if (!_adding)
              TextButton.icon(
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Add'),
                onPressed: () => setState(() => _adding = true),
              ),
          ],
        ),
        guardiansAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
          error: (_, _) => Text(
            'Could not load family.',
            style: theme.textTheme.bodySmall,
          ),
          data: (guardians) {
            if (guardians.isEmpty && !_adding) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'No guardians linked yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final g in guardians)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: PersonAvatar(name: g.name),
                    title: Row(
                      children: [
                        Expanded(child: Text(g.name)),
                        if (g.userId != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.check_circle,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                    subtitle: Text(
                      [
                        g.relationship,
                        g.phone,
                        g.email,
                        if (g.userId != null) 'Signed in',
                      ].whereType<String>().join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (g.userId == null)
                          IconButton(
                            tooltip: 'Send sign-in invite',
                            icon: const Icon(Icons.send_outlined, size: 20),
                            onPressed: () =>
                                _sendGuardianInvite(context, ref, g),
                          ),
                        IconButton(
                          tooltip: 'Unlink',
                          icon: const Icon(Icons.link_off, size: 20),
                          onPressed: () async {
                            await ref.read(guardianActionsProvider).unlink(
                                  guardianId: g.id,
                                  subjectId: widget.subjectId,
                                );
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        if (_adding) ...[
          const SizedBox(height: 8),
          _InlineAddGuardian(
            subjectId: widget.subjectId,
            onCancel: () => setState(() => _adding = false),
            onSaved: () => setState(() => _adding = false),
          ),
        ],
      ],
    );
  }
}

/// Expand-in-place "Add guardian" form. Lives inside [_GuardiansSection]
/// so the user keeps a single back stack — no second sheet to dismiss.
class _InlineAddGuardian extends ConsumerStatefulWidget {
  const _InlineAddGuardian({
    required this.subjectId,
    required this.onCancel,
    required this.onSaved,
  });

  final String subjectId;
  final VoidCallback onCancel;
  final VoidCallback onSaved;

  @override
  ConsumerState<_InlineAddGuardian> createState() =>
      _InlineAddGuardianState();
}

class _InlineAddGuardianState extends ConsumerState<_InlineAddGuardian> {
  final _name = TextEditingController();
  final _relationship = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  bool _isPrimary = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _relationship.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await runReported(
      library: 'guardians',
      action: () => ref.read(guardianActionsProvider).addToSubject(
            subjectId: widget.subjectId,
            name: name,
            relationship: _relationship.text.trim().isEmpty
                ? null
                : _relationship.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            isPrimary: _isPrimary,
          ),
    );
    if (!mounted) return;
    if (ok) {
      widget.onSaved();
      return;
    }
    setState(() {
      _saving = false;
      _error = 'Could not save. Please try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add guardian', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _relationship,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Relationship (e.g. Mother, Grandparent)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Primary guardian'),
            subtitle: const Text(
              'Shown first; default contact for daily reports.',
            ),
            value: _isPrimary,
            onChanged: (v) => setState(() => _isPrimary = v),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _saving ? null : widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
