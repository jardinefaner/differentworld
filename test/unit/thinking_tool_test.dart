// Phase 1 of the Thinking Tools vision (docs/THINKING_TOOLS.md): the unified
// ThinkingTool model + adapters prove that the two existing sources — the
// editorial Toolkit (reference) and the runnable activities — map into ONE
// shape. Pure data; no UI yet.

import 'package:differentworld/features/toolkit/toolkit_catalog.dart';
import 'package:differentworld/features/tools/thinking_tool.dart';
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

  group('buildToolLibrary', () {
    test('unifies both sources into one shelf, both kinds present', () {
      final lib = buildToolLibrary();
      final refCount =
          toolkitCatalog.fold<int>(0, (n, c) => n + c.tools.length);
      expect(lib.length, runnableThinkingTools.length + refCount);
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
