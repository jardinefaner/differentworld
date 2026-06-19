import 'dart:async';

import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/heroes/hero_catalog.dart';
import 'package:differentworld/features/heroes/widgets/hero_card.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/dismiss_guard.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// `/subjects/:id/hero` — the **Heroes** creator (docs/VISION.md 2026-06-19).
///
/// Teacher-paced (not kid-locked — staff + child build it together), a single
/// scrollable form that assembles a make-believe alter-ego: pick an animal +
/// skin, choose powers, name it `[Name] of [From]`, and snap + name a drawing.
/// A live [HeroCard] preview sits up top. Save upserts the child's one evolving
/// hero via `EntryActions.recordHero`.
class HeroCreatorScreen extends ConsumerStatefulWidget {
  const HeroCreatorScreen({
    required this.subjectId,
    this.displayName,
    this.groupId,
    super.key,
  });

  final String subjectId;
  final String? displayName;
  final String? groupId;

  @override
  ConsumerState<HeroCreatorScreen> createState() => _HeroCreatorScreenState();
}

class _HeroCreatorScreenState extends ConsumerState<HeroCreatorScreen> {
  HeroPick? _animal;
  HeroPick? _skin;
  final Set<String> _powerIds = <String>{};
  String? _from;
  final TextEditingController _name = TextEditingController();
  final TextEditingController _drawingName = TextEditingController();
  XFile? _drawingPhoto;
  Uint8List? _drawingBytes;
  bool _saving = false;
  bool _picking = false;

  @override
  void dispose() {
    _name.dispose();
    _drawingName.dispose();
    super.dispose();
  }

  List<HeroPick> get _powers =>
      heroPowers.where((p) => _powerIds.contains(p.id)).toList();

  HeroCardData get _draftData => HeroCardData(
    animal: _animal,
    skin: _skin,
    powers: _powers,
    name: _name.text.trim(),
    from: _from ?? '',
    drawingName: _drawingName.text.trim().isEmpty
        ? null
        : _drawingName.text.trim(),
  );

  HeroDraft? _buildDraft() {
    final animal = _animal;
    if (animal == null || _name.text.trim().isEmpty) return null;
    return HeroDraft(
      animal: animal,
      skin: _skin ?? const HeroPick('', '', ''),
      powers: _powers,
      name: _name.text.trim(),
      from: _from ?? '',
      drawingName: _drawingName.text.trim().isEmpty
          ? null
          : _drawingName.text.trim(),
    );
  }

  bool get _canSave => _animal != null && _name.text.trim().isNotEmpty;

  bool get _dirty =>
      _animal != null ||
      _skin != null ||
      _powerIds.isNotEmpty ||
      _from != null ||
      _name.text.trim().isNotEmpty ||
      _drawingPhoto != null;

  Future<void> _pickDrawing(ImageSource source) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await ref.read(photoServiceProvider).pickPhoto(source);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _drawingPhoto = picked;
        _drawingBytes = bytes;
      });
    } on Object catch (e) {
      if (kDebugMode) debugPrint('[heroes] drawing pick failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add that drawing.')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    final draft = _buildDraft();
    if (_saving || draft == null) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(entryActionsProvider);
    unawaited(HapticFeedback.mediumImpact());
    try {
      var photoUrls = const <String>[];
      var photoIds = const <String>[];
      final photo = _drawingPhoto;
      if (photo != null) {
        final attId = const Uuid().v4();
        final url = await ref
            .read(photoServiceProvider)
            .uploadOnly(
              entityKind: 'attachment',
              entityId: attId,
              picked: photo,
            );
        photoUrls = <String>[url];
        photoIds = <String>[attId];
      }
      await actions.recordHero(
        subjectId: widget.subjectId,
        draft: draft,
        groupId: widget.groupId,
        photoUrls: photoUrls,
        photoIds: photoIds,
      );
      if (!mounted) return;
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Saved ${draft.name}’s hero!')),
        );
    } on Object catch (e) {
      if (kDebugMode) debugPrint('[heroes] save failed: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save — try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.displayName?.trim();
    final title = (name != null && name.isNotEmpty)
        ? 'Make $name’s hero'
        : 'Make a hero';

    return DismissGuard(
      isDirty: () => _dirty && !_saving,
      child: EdgeScaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            children: [
              ContentHeader(
                title: title,
                subtitle: 'Build your animal, one piece at a time',
              ),
              HeroCard(data: _draftData),
              const SizedBox(height: 24),
              _section('Pick your animal'),
              _animalGrid(),
              const SizedBox(height: 24),
              _section('Pick a skin'),
              _skinChips(),
              const SizedBox(height: 24),
              _section(
                'Choose powers',
                trailing: '${_powerIds.length}/$heroMaxPowers',
              ),
              _powerChips(),
              const SizedBox(height: 24),
              _section('Name your hero'),
              _nameField(),
              const SizedBox(height: 12),
              _originChips(),
              const SizedBox(height: 24),
              _section('Draw it (optional)'),
              _drawingBlock(),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _canSave && !_saving
                    ? () => unawaited(_save())
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: const Text('Save my hero'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String label, {String? trailing}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _animalGrid() {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final a in heroAnimals)
          _PickTile(
            emoji: a.emoji,
            label: a.label,
            selected: _animal?.id == a.id,
            selectedColor: scheme.primaryContainer,
            onTap: () => setState(() => _animal = a),
          ),
      ],
    );
  }

  Widget _skinChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in heroSkins)
          ChoiceChip(
            label: Text('${s.emoji} ${s.label}'),
            selected: _skin?.id == s.id,
            onSelected: (_) => setState(
              () => _skin = _skin?.id == s.id ? null : s,
            ),
          ),
      ],
    );
  }

  Widget _powerChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in heroPowers)
          FilterChip(
            label: Text('${p.emoji} ${p.label}'),
            selected: _powerIds.contains(p.id),
            onSelected:
                (!_powerIds.contains(p.id) && _powerIds.length >= heroMaxPowers)
                ? null
                : (on) => setState(() {
                    if (on) {
                      _powerIds.add(p.id);
                    } else {
                      _powerIds.remove(p.id);
                    }
                  }),
          ),
      ],
    );
  }

  Widget _nameField() {
    return TextField(
      controller: _name,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(
        hintText: 'Their hero name (e.g. Luna)',
        border: OutlineInputBorder(),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _originChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in heroOrigins)
          ChoiceChip(
            label: Text(o),
            selected: _from == o,
            onSelected: (_) => setState(() => _from = _from == o ? null : o),
          ),
      ],
    );
  }

  Widget _drawingBlock() {
    final bytes = _drawingBytes;
    if (bytes != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  bytes,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Drawing added')),
              TextButton(
                onPressed: () => setState(() {
                  _drawingPhoto = null;
                  _drawingBytes = null;
                }),
                child: const Text('Remove'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _drawingName,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'What do they call it? (e.g. Sky-jumper)',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      );
    }
    return Row(
      children: [
        if (!kIsWeb) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _picking
                  ? null
                  : () => unawaited(_pickDrawing(ImageSource.camera)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Snap it'),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _picking
                ? null
                : () => unawaited(_pickDrawing(ImageSource.gallery)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose'),
          ),
        ),
      ],
    );
  }
}

/// A tappable animal tile — emoji over label, highlighted when selected.
class _PickTile extends StatelessWidget {
  const _PickTile({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 84,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? selectedColor : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(height: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
