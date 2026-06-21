import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/incidents/incidents_providers.dart';
import 'package:differentworld/features/incidents/templates/incident_report.dart';
import 'package:differentworld/features/incidents/widgets/incident_card.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/breakpoints.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/no_access.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

enum _IncidentFilter { all, needsFollowUp }

/// The incident log — every logged incident in the program, newest first
/// (docs/WORKFLOWS.md gap #3). A compliance surface: typed, child-scoped,
/// family-notification tracked. The "Needs follow-up" filter pairs with
/// the per-card "Mark notified" action — a director can see exactly which
/// families still need a call and work the list down. Scoped to what the
/// viewer can see (their cohorts; directors see all).
class IncidentsScreen extends ConsumerStatefulWidget {
  const IncidentsScreen({this.initialFilter, super.key});

  /// 'followup' opens the log pre-filtered to incidents whose family
  /// hasn't been notified — the Director's-Pulse deep link lands here.
  final String? initialFilter;

  @override
  ConsumerState<IncidentsScreen> createState() => _IncidentsScreenState();
}

class _IncidentsScreenState extends ConsumerState<IncidentsScreen> {
  late _IncidentFilter _filter = widget.initialFilter == 'followup'
      ? _IncidentFilter.needsFollowUp
      : _IncidentFilter.all;

  @override
  Widget build(BuildContext context) {
    final viewer = ref.watch(viewerProvider);
    if (!viewer.canObserve && !viewer.canManageSpace) {
      return const EdgeScaffold(body: NoAccess());
    }

    final incidentsAsync = ref.watch(incidentsInSpaceProvider);
    final subjectsById = <String, Subject>{
      for (final s
          in ref.watch(subjectsInSpaceProvider).value ?? const <Subject>[])
        s.id: s,
    };
    // App-wide "Bento everywhere" sweep — global-only toggle, no per-screen
    // provider. On → a responsive card grid; off → the calm single column.
    final bento = bentoEnabled(ref, perScreen: null);

    return EdgeScaffold(
      actions: [
        IconButton(
          tooltip: 'Export PDF',
          icon: const Icon(Icons.ios_share),
          onPressed: _export,
        ),
        if (viewer.canObserve)
          PrimaryActionButton(
            tooltip: 'Log an incident',
            icon: Icons.add,
            onPressed: () => context.push('/incidents/new'),
          ),
        const SyncStatusIndicator(),
      ],
      body: incidentsAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load incidents',
          onRetry: () => ref.invalidate(incidentsInSpaceProvider),
        ),
        data: (incidents) {
          if (incidents.isEmpty) {
            return EmptyState(
              icon: Icons.report_gmailerrorred_outlined,
              title: 'No incidents logged',
              message: viewer.canObserve
                  ? 'When something happens — a bump, a conflict, an '
                      'illness — log it here so there’s a record.'
                  : 'Incidents logged by staff will appear here.',
              action: viewer.canObserve
                  ? FilledButton.icon(
                      onPressed: () => context.push('/incidents/new'),
                      icon: const Icon(Icons.add),
                      label: const Text('Log an incident'),
                    )
                  : null,
            );
          }

          final needsCount =
              incidents.where((i) => !i.parentNotified).length;
          final filtered = _filter == _IncidentFilter.needsFollowUp
              ? incidents.where((i) => !i.parentNotified).toList()
              : incidents;
          final allClear = filtered.isEmpty;

          final header = _Header(
            filter: _filter,
            needsCount: needsCount,
            onFilter: (f) => setState(() => _filter = f),
          );

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: Breakpoints.splitMaxWidth,
              ),
              child: bento
                  // "Bento everywhere": header + filter chips stay full-
                  // width (they aren't cards); the incidents flow into a
                  // responsive card grid (1 col phone, 2-3 tablet/desktop)
                  // via the max-cross-axis-extent delegate. The card lays
                  // out at its natural height inside a fixed-height cell,
                  // clipped to fit so a long narrative truncates cleanly
                  // (IncidentCard is a shared widget — no maxLines to add).
                  ? CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(child: header),
                        if (allClear)
                          const SliverToBoxAdapter(child: _AllNotifiedNote())
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                            sliver: SliverGrid.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 240,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    mainAxisExtent: 220,
                                  ),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final incident = filtered[i];
                                return ClipRect(
                                  child: OverflowBox(
                                    minHeight: 0,
                                    maxHeight: double.infinity,
                                    alignment: Alignment.topCenter,
                                    child: IncidentCard(
                                      incident: incident,
                                      subject: subjectsById[incident.subjectId],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: (allClear ? 1 : filtered.length) + 1,
                      itemBuilder: (_, i) {
                        if (i == 0) return header;
                        if (allClear) return const _AllNotifiedNote();
                        final incident = filtered[i - 1];
                        return IncidentCard(
                          incident: incident,
                          subject: subjectsById[incident.subjectId],
                        );
                      },
                    ),
            ),
          );
        },
      ),
    );
  }

  /// Build a PDF of the currently-shown incidents (respecting the filter)
  /// and hand it to the OS share sheet — save to Files, print, or email
  /// for a licensing audit. Pure local bytes via the `printing` package,
  /// so it works offline (no Storage round-trip, no font fetch).
  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    final all = ref.read(incidentsInSpaceProvider).value ?? const <Incident>[];
    final filtered = _filter == _IncidentFilter.needsFollowUp
        ? all.where((i) => !i.parentNotified).toList()
        : all;
    if (filtered.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No incidents to export.')),
      );
      return;
    }
    final subjectsById = <String, Subject>{
      for (final s
          in ref.read(subjectsInSpaceProvider).value ?? const <Subject>[])
        s.id: s,
    };
    String nameFor(String? id) {
      final s = id == null ? null : subjectsById[id];
      return s == null ? 'A child' : '${s.firstName} ${s.lastName}'.trim();
    }

    final data = IncidentReportData(
      entries: [
        for (final inc in filtered)
          IncidentReportEntry(
            incident: inc,
            childName: nameFor(inc.subjectId),
          ),
      ],
      spaceName: ref.read(currentSpaceProvider).value?.name,
      title: _filter == _IncidentFilter.needsFollowUp
          ? 'Incidents needing follow-up'
          : 'Incident report',
      generatedAt: DateTime.now(),
    );
    try {
      final doc = await buildIncidentReportPdf(data);
      final bytes = await doc.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'incidents_${todayKey()}.pdf',
      );
    } on Object catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'incidents'),
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not export. Please try again.')),
      );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.filter,
    required this.needsCount,
    required this.onFilter,
  });

  final _IncidentFilter filter;
  final int needsCount;
  final ValueChanged<_IncidentFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: ContentHeader(title: 'Incidents'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: filter == _IncidentFilter.all,
                onSelected: (_) => onFilter(_IncidentFilter.all),
              ),
              ChoiceChip(
                label: Text(
                  needsCount > 0
                      ? 'Needs follow-up ($needsCount)'
                      : 'Needs follow-up',
                ),
                selected: filter == _IncidentFilter.needsFollowUp,
                onSelected: (_) => onFilter(_IncidentFilter.needsFollowUp),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AllNotifiedNote extends StatelessWidget {
  const _AllNotifiedNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Row(
        children: [
          Icon(
            Icons.mark_email_read_outlined,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'All families have been notified — nothing needs follow-up.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
