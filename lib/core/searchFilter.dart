// models/room_models.dart
class SearchFilters {
  final String searchQuery;
  final String location;
  final String roomType;
  final double minPrice;
  final double maxPrice;

  const SearchFilters({
    this.searchQuery = '',
    this.location = 'All',
    this.roomType = 'All',
    this.minPrice = 0,
    this.maxPrice = 10000,
  });

  SearchFilters copyWith({
    String? searchQuery,
    String? location,
    String? roomType,
    double? minPrice,
    double? maxPrice,
  }) {
    return SearchFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      location: location ?? this.location,
      roomType: roomType ?? this.roomType,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
    );
  }

  bool get hasActiveFilters {
    return searchQuery.isNotEmpty ||
        location != 'All' ||
        roomType != 'All' ||
        minPrice > 0 ||
        maxPrice < 10000;
  }
}

class RoomData {
  final String roomId;
  final Map<String, dynamic> room;
  final Map<String, dynamic> accommodation;

  RoomData({
    required this.roomId,
    required this.room,
    required this.accommodation,
  });
}
