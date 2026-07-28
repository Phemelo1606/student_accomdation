import 'package:flutter_test/flutter_test.dart';
import 'package:student_accomdation/core/searchFilter.dart';

void main() {
  group('SearchFilters', () {
    test('defaults have no active filters', () {
      const filters = SearchFilters();

      expect(filters.hasActiveFilters, isFalse);
      expect(filters.searchQuery, '');
      expect(filters.location, 'All');
      expect(filters.roomType, 'All');
      expect(filters.minPrice, 0);
      expect(filters.maxPrice, 10000);
    });

    test('hasActiveFilters is true when searchQuery is set', () {
      const filters = SearchFilters(searchQuery: 'campus');
      expect(filters.hasActiveFilters, isTrue);
    });

    test('hasActiveFilters is true when location is not All', () {
      const filters = SearchFilters(location: 'Downtown');
      expect(filters.hasActiveFilters, isTrue);
    });

    test('hasActiveFilters is true when price range is narrowed', () {
      expect(const SearchFilters(minPrice: 500).hasActiveFilters, isTrue);
      expect(const SearchFilters(maxPrice: 5000).hasActiveFilters, isTrue);
    });

    test('copyWith overrides only the given fields', () {
      const original = SearchFilters(
        searchQuery: 'a',
        location: 'Downtown',
        roomType: 'Single',
        minPrice: 100,
        maxPrice: 2000,
      );

      final updated = original.copyWith(searchQuery: 'b');

      expect(updated.searchQuery, 'b');
      expect(updated.location, 'Downtown');
      expect(updated.roomType, 'Single');
      expect(updated.minPrice, 100);
      expect(updated.maxPrice, 2000);
    });

    test('copyWith with no arguments returns equivalent values', () {
      const original = SearchFilters(searchQuery: 'a', location: 'Downtown');
      final copy = original.copyWith();

      expect(copy.searchQuery, original.searchQuery);
      expect(copy.location, original.location);
      expect(copy.roomType, original.roomType);
      expect(copy.minPrice, original.minPrice);
      expect(copy.maxPrice, original.maxPrice);
    });
  });
}
