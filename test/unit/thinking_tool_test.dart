// The Thinking Tools library (docs/THINKING_TOOLS.md). The unified ThinkingTool
// model + adapters prove the THREE sources — the runnable activities, the
// universal thinking tools (Phase 2), and the editorial Toolkit (reference) —
// merge into one shelf. Pure data.

import 'package:differentworld/features/toolkit/toolkit_catalog.dart';
import 'package:differentworld/features/tools/thinking_tool.dart';
import 'package:differentworld/features/tools/thinking_tools_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThinkingTool.fromToolkit', () {
    test('maps a reference tool: no route, carries when/why/script', () {
      final src = toolkitCatalog.first.tools.first;
      final tool = ThinkingTool.fromToolkit(src);
      expect(tool.kind, ToolKind.reference);
      expect(tool.isRunnable, isFalse);
      expect(tool.route, isNull);
      expect(tool.id, src.slug);
      expect(tool.name, src.name);
      expect(tool.script, src.quick);
      expect(tool.why, src.why);
      expect(tool.whenToUse, src.when);
      expect(tool.tags, contains(src.categoryId.name));
    });
  });

  group('runnableThinkingTools', () {
    test('every entry is runnable with a launch route + copy', () {
      expect(runnableThinkingTools, isNotEmpty);
      for (final t in runnableThinkingTools) {
        expect(t.kind, ToolKind.runnable);
        expect(t.isRunnable, isTrue);
        expect(t.route, isNotNull);
        expect(t.route, startsWith('/'));
        expect(t.name, isNotEmpty);
        expect(t.blurb, isNotEmpty);
        // Runnable tools have no reference face yet.
        expect(t.script, isNull);
      }
    });

    test('ids are unique', () {
      final ids = runnableThinkingTools.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('universalThinkingTools', () {
    test('every entry is a reference card with when/why/script', () {
      expect(universalThinkingTools, isNotEmpty);
      for (final t in universalThinkingTools) {
        expect(t.kind, ToolKind.reference);
        expect(t.isRunnable, isFalse);
        expect(t.route, isNull);
        expect(t.name, isNotEmpty);
        expect(t.blurb, isNotEmpty);
        expect(t.whenToUse, isNotNull);
        expect(t.why, isNotNull);
        expect(t.script, isNotNull);
        expect(t.tags, isNotEmpty);
      }
    });

    test('ids are unique', () {
      final ids = universalThinkingTools.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('buildToolLibrary', () {
    test('unifies all three sources into one shelf, both kinds present', () {
      final lib = buildToolLibrary();
      final refCount =
          toolkitCatalog.fold<int>(0, (n, c) => n + c.tools.length);
      expect(
        lib.length,
        runnableThinkingTools.length +
            universalThinkingTools.length +
            refCount,
      );
      expect(lib.any((t) => t.kind == ToolKind.runnable), isTrue);
      expect(lib.any((t) => t.kind == ToolKind.reference), isTrue);
    });

    test('runnable tools lead the shelf', () {
      final lib = buildToolLibrary();
      expect(lib.first.kind, ToolKind.runnable);
    });

    test('every tool has a non-empty search haystack', () {
      for (final t in buildToolLibrary()) {
        expect(t.searchHaystack.trim(), isNotEmpty);
      }
    });
  });
}
