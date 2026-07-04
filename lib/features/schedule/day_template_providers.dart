import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/schedule/day_template.dart';
import 'package:differentworld/features/settings/settings_actions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// The director's day-template library, live off the Space's caps. Reads
/// are offline-first (currentSpaceProvider is a Drift stream); writes are
/// optimistic through [DayTemplateActions].
final dayTemplatesProvider = Provider<List<DayTemplate>>((ref) {
  // Gate on the cap STRING, not the whole Space — currentSpaceProvider
  // emits on every space-row write (any cap), and we only re-decode when
  // the day_templates string itself changes.
  final raw = ref.watch(
    currentSpaceProvider.select(
      (s) => s.value?.caps.getString(SpaceCaps.dayTemplates),
    ),
  );
  return decodeDayTemplates(raw);
});

/// One template by id (null if it's been deleted).
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final dayTemplateByIdProvider = Provider.family<DayTemplate?, String>((
  ref,
  id,
) {
  for (final t in ref.watch(dayTemplatesProvider)) {
    if (t.id == id) return t;
  }
  return null;
});

/// Mutations on the day-template library. Each write is a read-modify-write
/// of the JSON on `spaces.capabilities` (other caps are preserved by
/// `Capabilities.setting`). Optimistic + offline-first like every other
/// write — local Drift first, PowerSync later.
class DayTemplateActions {
  DayTemplateActions(this._ref);
  final Ref _ref;
  static const _uuid = Uuid();

  Future<List<DayTemplate>> _load(String spaceId) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final s = await db.spacesDao.findById(spaceId);
    return decodeDayTemplates(s?.caps.getString(SpaceCaps.dayTemplates));
  }

  Future<void> _save(String spaceId, List<DayTemplate> list) {
    return _ref
        .read(spaceCapActionsProvider)
        .setStringCap(
          spaceId,
          SpaceCaps.dayTemplates,
          encodeDayTemplates(list),
        );
  }

  // Serialize every read-modify-write. The library lives in ONE caps JSON
  // string, so two concurrent mutations (e.g. a drag-reorder's
  // unawaited write racing a block delete) would both read the same
  // pre-write state and the second `_save` would silently clobber the
  // first. Chaining through `_pending` makes them apply in order.
  Future<void> _pending = Future<void>.value();

  Future<void> _mutate(
    String spaceId,
    List<DayTemplate> Function(List<DayTemplate> list) update,
  ) {
    final op = _pending.then((_) async {
      final list = await _load(spaceId);
      await _save(spaceId, update(List<DayTemplate>.of(list)));
    });
    // The queue's tail must never be a rejected future, or one failed
    // write would block every later mutation. Callers still see this op's
    // own error via the returned `op`.
    _pending = op.catchError((Object _) {});
    return op;
  }

  List<DayTemplate> _replace(
    List<DayTemplate> list,
    String id,
    DayTemplate Function(DayTemplate t) update,
  ) => [
    for (final t in list)
      if (t.id == id) update(t) else t,
  ];

  /// Create a starter template and return its id (so the caller can open
  /// the editor on it).
  Future<String> createTemplate({
    required String spaceId,
    required String name,
  }) async {
    final template = DayTemplate.starter(name: name);
    await _mutate(spaceId, (list) => [...list, template]);
    return template.id;
  }

  Future<void> renameTemplate({
    required String spaceId,
    required String id,
    required String name,
  }) => _mutate(spaceId, (l) => _replace(l, id, (t) => t.copyWith(name: name)));

  Future<void> setBounds({
    required String spaceId,
    required String id,
    required int startMinute,
    required int endMinute,
  }) => _mutate(
    spaceId,
    (l) => _replace(
      l,
      id,
      (t) => t.copyWith(startMinute: startMinute, endMinute: endMinute),
    ),
  );

  Future<void> addBlock({
    required String spaceId,
    required String templateId,
    required String label,
    required int minutes,
    required DayBlockKind kind,
  }) {
    final block = DayBlock(
      id: _uuid.v4(),
      label: label.trim().isEmpty ? kind.label : label.trim(),
      minutes: minutes,
      kind: kind,
    );
    return _mutate(
      spaceId,
      (l) => _replace(
        l,
        templateId,
        (t) => t.copyWith(blocks: [...t.blocks, block]),
      ),
    );
  }

  Future<void> updateBlock({
    required String spaceId,
    required String templateId,
    required String blockId,
    String? label,
    int? minutes,
    DayBlockKind? kind,
    double? energy,
  }) => _mutate(
    spaceId,
    (l) => _replace(
      l,
      templateId,
      (t) => t.copyWith(
        blocks: [
          for (final b in t.blocks)
            if (b.id == blockId)
              b.copyWith(
                label: label,
                minutes: minutes,
                kind: kind,
                energy: energy,
              )
            else
              b,
        ],
      ),
    ),
  );

  Future<void> removeBlock({
    required String spaceId,
    required String templateId,
    required String blockId,
  }) => _mutate(
    spaceId,
    (l) => _replace(
      l,
      templateId,
      (t) => t.copyWith(
        blocks: [
          for (final b in t.blocks)
            if (b.id != blockId) b,
        ],
      ),
    ),
  );

  Future<void> reorderBlocks({
    required String spaceId,
    required String templateId,
    required int oldIndex,
    required int newIndex,
  }) => _mutate(
    spaceId,
    (l) => _replace(l, templateId, (t) {
      final blocks = List<DayBlock>.of(t.blocks);
      if (oldIndex < 0 || oldIndex >= blocks.length) return t;
      // ReorderableListView's newIndex is post-removal-adjusted.
      var target = newIndex;
      if (target > oldIndex) target -= 1;
      target = target.clamp(0, blocks.length - 1);
      final moved = blocks.removeAt(oldIndex);
      blocks.insert(target, moved);
      return t.copyWith(blocks: blocks);
    }),
  );

  Future<void> deleteTemplate({
    required String spaceId,
    required String id,
  }) => _mutate(
    spaceId,
    (l) => [
      for (final t in l)
        if (t.id != id) t,
    ],
  );

  /// Re-add a deleted template verbatim — the `deleteWithUndo` undo path.
  /// The library lives in the caps JSON (no Drift row), so restore re-inserts
  /// the [DayTemplate] model through the same serialized `_mutate` queue as
  /// every other edit. Idempotent: if a row with this id already exists (a
  /// double-undo race) it is replaced, never duplicated.
  Future<void> restoreTemplate({
    required String spaceId,
    required DayTemplate template,
  }) => _mutate(
    spaceId,
    (l) => [
      for (final t in l)
        if (t.id != template.id) t,
      template,
    ],
  );

  /// Materialize a template onto a specific date for one or more groups —
  /// packs the duration-blocks into clock windows on [date] and writes real
  /// `schedule_blocks` (which Today / the live "now" / the family lens all
  /// read). Returns the number of blocks created. Existing blocks are NOT
  /// removed (the caller confirms first if the day already has some).
  Future<int> applyToDate({
    required String spaceId,
    required String templateId,
    required DateTime date,
    required List<String> groupIds,
  }) async {
    final list = await _load(spaceId);
    DayTemplate? template;
    for (final t in list) {
      if (t.id == templateId) template = t;
    }
    if (template == null) return 0;
    return applyTemplateToDate(
      spaceId: spaceId,
      template: template,
      date: date,
      groupIds: groupIds,
    );
  }

  /// Materialize a template OBJECT (not a saved id) onto a date for one or more
  /// groups — the path the "propose the day" draft uses, so a proposed day can
  /// be applied without first saving it to the library. Same packing →
  /// `schedule_blocks` as [applyToDate]; existing blocks are NOT removed (the
  /// caller confirms first if the day already has some).
  Future<int> applyTemplateToDate({
    required String spaceId,
    required DayTemplate template,
    required DateTime date,
    required List<String> groupIds,
  }) async {
    if (template.blocks.isEmpty || groupIds.isEmpty) return 0;
    final day = DateTime(date.year, date.month, date.day);
    final dateKey =
        '${day.year.toString().padLeft(4, '0')}-'
        '${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    final specs = [
      for (final slot in template.schedule)
        (
          title: slot.block.label,
          kind: slot.block.kind.scheduleKind,
          startAt: day.add(Duration(minutes: slot.startMinute)),
          endAt: day.add(Duration(minutes: slot.endMinute)),
        ),
    ];
    final db = await _ref.read(appDatabaseProvider.future);
    var written = 0;
    for (final groupId in groupIds) {
      final ids = await db.scheduleDao.createDayBlocks(
        spaceId: spaceId,
        groupId: groupId,
        date: dateKey,
        blocks: specs,
      );
      written += ids.length;
    }
    return written;
  }
}

final dayTemplateActionsProvider = Provider<DayTemplateActions>(
  DayTemplateActions.new,
);
