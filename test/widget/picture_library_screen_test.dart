// Widget test for the staff picture library (Wave 1b). Verifies the empty +
// data states render; uses a `pending:` picture so the tile shows its
// placeholder (not the signed-URL network path) — no Supabase in the harness.

import 'package:differentworld/features/game_content/custom_pictures.dart';
import 'package:differentworld/features/game_content/picture_library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  Widget harness(List<CustomPicture> pics) {
    final router = GoRouter(
      initialLocation: '/games/pictures',
      routes: [
        GoRoute(
          path: '/games/pictures',
          builder: (_, _) => const PictureLibraryScreen(),
        ),
        GoRoute(
          path: '/today',
          builder: (_, _) => const Scaffold(body: Text('today')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        customPicturesProvider.overrideWith((ref) => Stream.value(pics)),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }

  testWidgets('empty state invites adding the first picture', (tester) async {
    await tester.pumpWidget(harness(const []));
    await tester.pumpAndSettle();

    expect(find.text('No pictures yet'), findsOneWidget);
    expect(find.text('Add pictures'), findsWidgets);
  });

  testWidgets('data state shows the label, the add tile, and the mix toggle', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(const [
        CustomPicture(id: 'p1', label: 'Our class dog', path: 'pending:p1'),
      ]),
    );
    // NOT pumpAndSettle: the pending tile's CircularProgressIndicator animates
    // forever, so we pump fixed frames to let the stream + provider emit.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Our class dog'), findsOneWidget);
    // The pending tile shows its "uploading…" chip rather than the network image.
    expect(find.text('uploading…'), findsOneWidget);
    expect(find.text('Add pictures'), findsWidgets);
  });
}
