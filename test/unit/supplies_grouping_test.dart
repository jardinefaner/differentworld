// Pure view-logic for the supplies list (docs/SUPPLIES.md): category
// labelling, low-stock detection, and the header/tile flattening.

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/supplies/supplies_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

Supply _supply({
  required String name,
  String? category,
  double? quantity,
  double? lowStockThreshold,
}) => Supply(
  id: name,
  spaceId: 'space-1',
  name: name,
  category: category,
  quantity: quantity,
  lowStockThreshold: lowStockThreshold,
  createdAt: '2026-06-01T00:00:00Z',
  updatedAt: '2026-06-01T00:00:00Z',
);

void main() {
  group('supplyCategoryLabel', () {
    test('falls back to Uncategorized when blank or null', () {
      expect(supplyCategoryLabel(_supply(name: 'A')), 'Uncategorized');
      expect(supplyCategoryLabel(_supply(name: 'A', category: '   ')), 'Uncategorized');
    });

    test('trims a real category', () {
      expect(supplyCategoryLabel(_supply(name: 'A', category: '  Art ')), 'Art');
    });
  });

  group('isLowStock', () {
    test('needs both a quantity and a threshold', () {
      expect(isLowStock(_supply(name: 'A', quantity: 1)), isFalse);
      expect(isLowStock(_supply(name: 'A', lowStockThreshold: 1)), isFalse);
      expect(isLowStock(_supply(name: 'A')), isFalse);
    });

    test('low when quantity is at or below the threshold', () {
      expect(isLowStock(_supply(name: 'A', quantity: 2, lowStockThreshold: 3)), isTrue);
      expect(isLowStock(_supply(name: 'A', quantity: 3, lowStockThreshold: 3)), isTrue);
      expect(isLowStock(_supply(name: 'A', quantity: 4, lowStockThreshold: 3)), isFalse);
    });
  });

  group('groupSuppliesByCategory', () {
    test('emits a header when the category changes', () {
      final rows = groupSuppliesByCategory([
        _supply(name: 'Markers', category: 'Art'),
        _supply(name: 'Paper', category: 'Art'),
        _supply(name: 'Balls', category: 'Sports'),
      ]);
      expect(rows, hasLength(5)); // Art, Markers, Paper, Sports, Balls
      expect(rows[0], 'Art');
      expect((rows[1] as Supply).name, 'Markers');
      expect((rows[2] as Supply).name, 'Paper');
      expect(rows[3], 'Sports');
      expect((rows[4] as Supply).name, 'Balls');
    });

    test('uncategorized rows group under one Uncategorized header', () {
      final rows = groupSuppliesByCategory([
        _supply(name: 'Mystery box'),
        _supply(name: 'Spare thing'),
      ]);
      expect(rows.whereType<String>().toList(), ['Uncategorized']);
      expect(rows.whereType<Supply>(), hasLength(2));
    });

    test('empty in, empty out', () {
      expect(groupSuppliesByCategory(const []), isEmpty);
    });
  });

  group('formatSupplyNumber', () {
    test('drops the .0 on whole numbers', () {
      expect(formatSupplyNumber(12), '12');
      expect(formatSupplyNumber(1.5), '1.5');
    });
  });
}
