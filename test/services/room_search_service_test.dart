import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_accomdation/core/searchFilter.dart';
import 'package:student_accomdation/services/RoomSearchService.dart';

RoomData _room({
  required String roomId,
  required String roomType,
  required num monthlyRent,
  String? description,
  String? roomNumber,
  required String accommodationName,
  required String location,
}) {
  return RoomData(
    roomId: roomId,
    room: {
      'RoomType': roomType,
      'MonthlyRent': monthlyRent,
      if (description != null) 'Description': description,
      if (roomNumber != null) 'RoomNumber': roomNumber,
    },
    accommodation: {
      'Name': accommodationName,
      'Location': location,
    },
  );
}

void main() {
  // filterRooms/getFilterOptions never touch Firestore, but the constructor's
  // field initializer does (`FirebaseFirestore.instance`), so a fake instance
  // is still required to construct the service in a plain unit test.
  final service = RoomSearchService(firestore: FakeFirebaseFirestore());

  final rooms = [
    _room(
      roomId: '1',
      roomType: 'Single',
      monthlyRent: 1500,
      description: 'Quiet room near campus',
      roomNumber: 'A1',
      accommodationName: 'Sunrise Residence',
      location: 'Downtown',
    ),
    _room(
      roomId: '2',
      roomType: 'Shared',
      monthlyRent: 800,
      description: 'Budget-friendly shared room',
      roomNumber: 'B2',
      accommodationName: 'Campus View',
      location: 'Northside',
    ),
    _room(
      roomId: '3',
      roomType: 'Single',
      monthlyRent: 3000,
      description: 'Luxury ensuite',
      roomNumber: 'C3',
      accommodationName: 'The Heights',
      location: 'Downtown',
    ),
  ];

  group('RoomSearchService.filterRooms', () {
    test('returns all rooms when filters are default', () {
      final result = service.filterRooms(rooms, const SearchFilters());
      expect(result.length, 3);
    });

    test('filters by search query across accommodation name, location, room type, description and room number',
        () {
      expect(
        service
            .filterRooms(rooms, const SearchFilters(searchQuery: 'sunrise'))
            .map((r) => r.roomId),
        ['1'],
      );
      expect(
        service
            .filterRooms(rooms, const SearchFilters(searchQuery: 'northside'))
            .map((r) => r.roomId),
        ['2'],
      );
      expect(
        service
            .filterRooms(rooms, const SearchFilters(searchQuery: 'luxury'))
            .map((r) => r.roomId),
        ['3'],
      );
      expect(
        service
            .filterRooms(rooms, const SearchFilters(searchQuery: 'b2'))
            .map((r) => r.roomId),
        ['2'],
      );
    });

    test('search query is case-insensitive', () {
      final result =
          service.filterRooms(rooms, const SearchFilters(searchQuery: 'SUNRISE'));
      expect(result.map((r) => r.roomId), ['1']);
    });

    test('filters by exact location match', () {
      final result =
          service.filterRooms(rooms, const SearchFilters(location: 'Downtown'));
      expect(result.map((r) => r.roomId).toSet(), {'1', '3'});
    });

    test('filters by exact room type match', () {
      final result =
          service.filterRooms(rooms, const SearchFilters(roomType: 'Shared'));
      expect(result.map((r) => r.roomId), ['2']);
    });

    test('filters by price range (inclusive bounds)', () {
      final result = service.filterRooms(
        rooms,
        const SearchFilters(minPrice: 1000, maxPrice: 2000),
      );
      expect(result.map((r) => r.roomId), ['1']);
    });

    test('combines multiple filters with AND semantics', () {
      final result = service.filterRooms(
        rooms,
        const SearchFilters(location: 'Downtown', roomType: 'Single', maxPrice: 2000),
      );
      expect(result.map((r) => r.roomId), ['1']);
    });

    test('returns empty list when nothing matches', () {
      final result =
          service.filterRooms(rooms, const SearchFilters(searchQuery: 'nonexistent'));
      expect(result, isEmpty);
    });
  });

  group('RoomSearchService.getFilterOptions', () {
    test('collects unique, sorted locations and room types, always including All', () async {
      final options = await service.getFilterOptions(rooms);

      expect(options['locations'], ['All', 'Downtown', 'Northside']);
      expect(options['roomTypes'], ['All', 'Shared', 'Single']);
    });

    test('returns only All for an empty room list', () async {
      final options = await service.getFilterOptions([]);

      expect(options['locations'], ['All']);
      expect(options['roomTypes'], ['All']);
    });
  });
}
