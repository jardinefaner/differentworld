import 'package:differentworld/features/entities/entity_link.dart';
import 'package:differentworld/features/entities/entity_match.dart';
import 'package:differentworld/features/entities/entity_providers.dart';
import 'package:differentworld/features/entities/entity_ref.dart';
import 'package:differentworld/features/entities/linkified_text.dart';
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget-level contract for the live-entities surface: the toggle degrades
/// cleanly to plain text, and the family scope is a hard privacy boundary
/// (autotag never fires) — the things the pure matcher test can't see.
class _LiveStub extends LiveEntitiesNotifier {
  // A one-arg test stub for the on/off toggle; a named param is needless here.
  // ignore: avoid_positional_boolean_parameters
  _LiveStub(this.value);
  final bool value;
  // Synchronous so there's no loading frame (during which liveEntitiesOn
  // defaults to ON) — the test asserts the RESOLVED state directly.
  @override
  Future<bool> build() => SynchronousFuture(value);
}

void main() {
  const sofia = EntityRef(kind: EntityKind.subject, id: 's1', label: 'Sofia');

  Widget host(
    Widget child, {
    required bool live,
    List<EntityMatchTerm> index = const [],
  }) {
    return ProviderScope(
      overrides: [
        liveEntitiesProvider.overrideWith(() => _LiveStub(live)),
        entityIndexProvider.overrideWithValue(index),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('EntityLink is a tappable link when live entities are on',
      (tester) async {
    await tester.pumpWidget(host(const EntityLink(entity: sofia), live: true));
    await tester.pumpAndSettle();
    expect(find.text('Sofia'), findsOneWidget);
    expect(find.byType(InkWell), findsOneWidget);
  });

  testWidgets('EntityLink degrades to plain text when live entities are off',
      (tester) async {
    await tester.pumpWidget(host(const EntityLink(entity: sofia), live: false));
    await tester.pumpAndSettle();
    expect(find.text('Sofia'), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('LinkifiedText autotags in staff scope but stays plain for family',
      (tester) async {
    const index = [
      EntityMatchTerm(text: 'Sofia', ref: sofia, properNounOnly: true),
    ];

    // Staff: the body becomes rich — the matched name carries a tap span.
    await tester.pumpWidget(
      host(const LinkifiedText('Sofia played'), live: true, index: index),
    );
    await tester.pumpAndSettle();
    final staffText = tester.widget<Text>(find.byType(Text).first);
    expect(staffText.textSpan, isNotNull);
    expect(staffText.data, isNull);

    // Family: plain Text, no autotag — the privacy boundary holds even with a
    // matching index loaded.
    await tester.pumpWidget(
      host(
        const LinkifiedText('Sofia played', scope: EntityScope.family),
        live: true,
        index: index,
      ),
    );
    await tester.pumpAndSettle();
    final familyText = tester.widget<Text>(find.byType(Text).first);
    expect(familyText.data, 'Sofia played');
  });
}
