// services/room_search_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:student_accomdation/core/searchFilter.dart';
import 'package:student_accomdation/core/app_logger.dart';


class RoomSearchService {
  final FirebaseFirestore _firestore;

  RoomSearchService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Get all available rooms
  Future<List<RoomData>> getAllAvailableRooms() async {
    List<RoomData> allAvailableRooms = [];

    try {
      final landlordsSnapshot = await _firestore.collection("landlords").get();

      for (final landlordDoc in landlordsSnapshot.docs) {
        final landlordId = landlordDoc.id;

        final accommodationsSnapshot = await _firestore
            .collection("landlords")
            .doc(landlordId)
            .collection("accommodations")
            .get();

        for (final accDoc in accommodationsSnapshot.docs) {
          final accommodationId = accDoc.id;
          final accommodationData = accDoc.data();

          // Try Accommodations collection first
          try {
            final roomsSnapshot = await _firestore
                .collection("Accommodations")
                .doc(accommodationId)
                .collection("Rooms")
                .where("AvailabilityStatus", isEqualTo: "Available")
                .get();

            for (final roomDoc in roomsSnapshot.docs) {
              final roomData = roomDoc.data();
              allAvailableRooms.add(RoomData(
                roomId: roomDoc.id,
                room: roomData,
                accommodation: accommodationData,
              ));
            }
          } catch (e) {
            // Try landlord's accommodations collection
            try {
              final roomsSnapshot = await _firestore
                  .collection("landlords")
                  .doc(landlordId)
                  .collection("accommodations")
                  .doc(accommodationId)
                  .collection("rooms")
                  .where("AvailabilityStatus", isEqualTo: "Available")
                  .get();

              for (final roomDoc in roomsSnapshot.docs) {
                final roomData = roomDoc.data();
                allAvailableRooms.add(RoomData(
                  roomId: roomDoc.id,
                  room: roomData,
                  accommodation: accommodationData,
                ));
              }
            } catch (e2) {
              // Continue to next accommodation
            }
          }
        }
      }
    } catch (e) {
      AppLogger.log("Error fetching rooms: $e");
    }

    return allAvailableRooms;
  }

  // Filter rooms based on criteria
  List<RoomData> filterRooms(List<RoomData> rooms, SearchFilters filters) {
    return rooms.where((roomData) {
      return _roomMatchesFilters(roomData, filters);
    }).toList();
  }

  bool _roomMatchesFilters(RoomData roomData, SearchFilters filters) {
    final room = roomData.room;
    final accommodation = roomData.accommodation;

    // Search query filter
    if (filters.searchQuery.isNotEmpty) {
      final query = filters.searchQuery.toLowerCase();
      final matchesSearch =
          (accommodation['Name']?.toString().toLowerCase().contains(query) ??
                  false) ||
              (accommodation['Location']
                      ?.toString()
                      .toLowerCase()
                      .contains(query) ??
                  false) ||
              (room['RoomType']?.toString().toLowerCase().contains(query) ??
                  false) ||
              (room['Description']?.toString().toLowerCase().contains(query) ??
                  false) ||
              (room['RoomNumber']?.toString().toLowerCase().contains(query) ??
                  false);

      if (!matchesSearch) return false;
    }

    // Location filter
    if (filters.location != 'All') {
      if (accommodation['Location'] != filters.location) {
        return false;
      }
    }

    // Room type filter
    if (filters.roomType != 'All') {
      if (room['RoomType'] != filters.roomType) {
        return false;
      }
    }

    // Price filter
    final price = room['MonthlyRent']?.toDouble() ?? 0.0;
    if (price < filters.minPrice || price > filters.maxPrice) {
      return false;
    }

    return true;
  }

  // Get available filter options from rooms data
  Future<Map<String, List<String>>> getFilterOptions(
      List<RoomData> rooms) async {
    final Set<String> locations = {'All'};
    final Set<String> roomTypes = {'All'};

    for (final roomData in rooms) {
      // Add location
      if (roomData.accommodation['Location'] != null) {
        locations.add(roomData.accommodation['Location']);
      }

      // Add room type
      if (roomData.room['RoomType'] != null) {
        roomTypes.add(roomData.room['RoomType']);
      }
    }

    return {
      'locations': locations.toList()..sort(),
      'roomTypes': roomTypes.toList()..sort(),
    };
  }

  // Get stream of rooms (for real-time updates)
  Stream<List<RoomData>> getRoomsStream() {
    return _firestore
        .collection("landlords")
        .snapshots()
        .asyncMap((snapshot) async {
      List<RoomData> rooms = [];

      for (final landlordDoc in snapshot.docs) {
        final landlordId = landlordDoc.id;

        final accommodationsSnapshot = await _firestore
            .collection("landlords")
            .doc(landlordId)
            .collection("accommodations")
            .get();

        for (final accDoc in accommodationsSnapshot.docs) {
          final accommodationId = accDoc.id;
          final accommodationData = accDoc.data();

          // Try both collection patterns
          await _addRoomsFromCollection(
            rooms,
            _firestore
                .collection("Accommodations")
                .doc(accommodationId)
                .collection("Rooms"),
            accommodationData,
          );

          await _addRoomsFromCollection(
            rooms,
            _firestore
                .collection("landlords")
                .doc(landlordId)
                .collection("accommodations")
                .doc(accommodationId)
                .collection("rooms"),
            accommodationData,
          );
        }
      }

      return rooms;
    });
  }

  Future<void> _addRoomsFromCollection(
    List<RoomData> rooms,
    CollectionReference collectionRef,
    Map<String, dynamic> accommodationData,
  ) async {
    try {
      final roomsSnapshot = await collectionRef
          .where("AvailabilityStatus", isEqualTo: "Available")
          .get();

      for (final roomDoc in roomsSnapshot.docs) {
        final roomData = roomDoc.data() as Map<String, dynamic>;
        rooms.add(RoomData(
          roomId: roomDoc.id,
          room: roomData,
          accommodation: accommodationData,
        ));
      }
    } catch (e) {
      // Collection might not exist, which is fine
    }
  }
}
