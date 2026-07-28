// student_home_page.dart
import 'package:flutter/material.dart';
import 'package:student_accomdation/core/searchFilter.dart';
import 'package:student_accomdation/pages/saved_accommodations_page.dart';
import 'package:student_accomdation/services/RoomSearchService.dart';
import 'package:student_accomdation/services/favorites_service.dart';
import 'package:student_accomdation/widgets/search_filter_widgets.dart';
import 'package:student_accomdation/pages/room_booking_page.dart';
import 'package:student_accomdation/pages/studentProfile.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  final RoomSearchService _searchService = RoomSearchService();
  final FavoritesService _favoritesService = FavoritesService();
  late SearchFilters _filters;
  late Future<List<RoomData>> _roomsFuture;
  late Future<Map<String, List<String>>> _filterOptionsFuture;

  @override
  void initState() {
    super.initState();
    _filters = const SearchFilters();
    _roomsFuture = _searchService.getAllAvailableRooms();
    _filterOptionsFuture = _getFilterOptions();
  }

  Future<Map<String, List<String>>> _getFilterOptions() async {
    final rooms = await _roomsFuture;
    return _searchService.getFilterOptions(rooms);
  }

  void _onFiltersChanged(SearchFilters newFilters) {
    setState(() {
      _filters = newFilters;
    });
  }

  void _refreshData() {
    setState(() {
      _roomsFuture = _searchService.getAllAvailableRooms();
      _filterOptionsFuture = _getFilterOptions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A168C),
      body: SafeArea(
        child: Column(
          children: [
            // Search and Filters Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: FutureBuilder<Map<String, List<String>>>(
                future: _filterOptionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            child: TextField(
                              enabled: false,
                              decoration: InputDecoration(
                                hintText: "Loading search...",
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          Icon(Icons.search, color: Colors.grey),
                          SizedBox(width: 8),
                          Icon(Icons.filter_list, color: Colors.grey),
                        ],
                      ),
                    );
                  }

                  return SearchBarWithFilters(
                    initialFilters: _filters,
                    onFiltersChanged: _onFiltersChanged,
                    filterOptions: snapshot.data ??
                        {
                          'locations': ['All'],
                          'roomTypes': ['All'],
                        },
                  );
                },
              ),
            ),

            // White Background Container for Content
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: _buildRoomsList(),
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1A168C),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: "Saved",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: "Alerts",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
        onTap: (index) {
          if (index == 1) {
            // Saved tab
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SavedAccommodationsPage(),
              ),
            );
          }
          if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudentProfileScreen(),
              ),
            );
          }
          // Add navigation logic for other tabs if needed
        },
      ),

      // Refresh Button
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshData,
        backgroundColor: const Color(0xFF1A168C),
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildRoomsList() {
    return FutureBuilder<List<RoomData>>(
      future: _roomsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState("No available rooms found");
        }

        final allRooms = snapshot.data!;
        final filteredRooms = _searchService.filterRooms(allRooms, _filters);

        if (filteredRooms.isEmpty) {
          return _buildEmptyState("No rooms match your search criteria");
        }

        return Column(
          children: [
            // Results count and clear filters
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    '${filteredRooms.length} room${filteredRooms.length == 1 ? '' : 's'} found',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (_filters.hasActiveFilters)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _filters = const SearchFilters();
                        });
                      },
                      child: const Text(
                        'Clear Filters',
                        style: TextStyle(color: Color(0xFF1A168C)),
                      ),
                    ),
                ],
              ),
            ),

            // Rooms list
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _refreshData();
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: filteredRooms.length,
                  itemBuilder: (context, index) {
                    final roomData = filteredRooms[index];
                    return _buildRoomCard(context, roomData.roomId,
                        roomData.room, roomData.accommodation);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
              message.contains("match") ? Icons.search_off : Icons.meeting_room,
              size: 80,
              color: Colors.grey.shade400),
          const SizedBox(height: 24),
          Text(
            message,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (message.contains("match"))
            Column(
              children: [
                const Text(
                  "Try adjusting your search criteria or filters",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _filters = const SearchFilters();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A168C),
                  ),
                  child: const Text(
                    'Clear All Filters',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            )
          else
            const Text(
              "Check back later for new room listings",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
        ],
      ),
    );
  }

  // Update the _buildRoomCard method to include save button
  Widget _buildRoomCard(BuildContext context, String roomId,
      Map<String, dynamic> room, Map<String, dynamic> accommodation) {
    final List<String> images = List<String>.from(room['Images'] ?? []);
    final String accommodationName =
        accommodation["Name"] ?? "Unknown Accommodation";
    final String accommodationLocation =
        accommodation["Location"] ?? "Location not specified";
    final String accommodationId = accommodation["id"] ??
        accommodation["Id"] ??
        accommodation["accommodationId"] ??
        'temp_$roomId';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Room Images with Save Button
            if (images.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          itemBuilder: (context, index) {
                            return Container(
                              width: 160,
                              margin: EdgeInsets.only(
                                  right: index < images.length - 1 ? 8 : 0,
                                  bottom: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  images[index],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.broken_image,
                                          color: Colors.grey),
                                    );
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: _buildSaveButton(
                            accommodationId, accommodation, room, roomId),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),

            // Accommodation Info
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.apartment,
                      size: 16, color: Color(0xFF1A237E)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          accommodationName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                        Text(
                          accommodationLocation,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Header with Room Number and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Room ${room['RoomNumber'] ?? 'N/A'}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A237E),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(room['AvailabilityStatus']),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    room['AvailabilityStatus'] ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Room Details
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildDetailItem(Icons.category, room['RoomType'] ?? 'N/A'),
                _buildDetailItem(
                    Icons.people, "${room['Capacity'] ?? 'N/A'} persons"),
                _buildDetailItem(Icons.attach_money,
                    "R${room['MonthlyRent']?.toStringAsFixed(0) ?? 'N/A'}/month"),
              ],
            ),
            const SizedBox(height: 8),

            // Description
            if (room['Description'] != null && room['Description'].isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    room['Description'],
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),

            // Amenities
            if (room['Amenities'] != null &&
                (room['Amenities'] as List).isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: (room['Amenities'] as List).map((amenity) {
                      return Chip(
                        label: Text(amenity),
                        backgroundColor: Colors.blue.shade50,
                        labelStyle: const TextStyle(fontSize: 12),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      );
                    }).toList(),
                  ),
                ],
              ),

            const SizedBox(height: 12),

            // Action Button - Book Now
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _bookRoom(context, roomId, room, accommodation);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD600),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  "Book This Room",
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// Add this method for the save button
  Widget _buildSaveButton(
    String accommodationId,
    Map<String, dynamic> accommodation,
    Map<String, dynamic> room,
    String roomId,
  ) {
    return FutureBuilder<bool>(
      future: _favoritesService.isAccommodationSaved(accommodationId),
      builder: (context, snapshot) {
        final isSaved = snapshot.data ?? false;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              isSaved ? Icons.favorite : Icons.favorite_border,
              color: isSaved ? Colors.red : Colors.grey,
              size: 20,
            ),
            onPressed: () => _toggleSaveAccommodation(
              accommodationId,
              accommodation,
              room,
              roomId,
              isSaved,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "Available":
        return Colors.green;
      case "Occupied":
        return Colors.red;
      case "Under Maintenance":
        return Colors.orange;
      case "Reserved":
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _bookRoom(BuildContext context, String roomId, Map<String, dynamic> room,
      Map<String, dynamic> accommodation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoomBookingPage(
          room: room,
          accommodation: accommodation,
          roomId: roomId,
        ),
      ),
    );
  }

  void _showBookingConfirmation(BuildContext context, Map<String, dynamic> room,
      Map<String, dynamic> accommodation) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Booking request sent for Room ${room['RoomNumber']}"),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Add this method to handle save/unsave
  Future<void> _toggleSaveAccommodation(
    String accommodationId,
    Map<String, dynamic> accommodation,
    Map<String, dynamic> room,
    String roomId,
    bool isCurrentlySaved,
  ) async {
    try {
      if (isCurrentlySaved) {
        await _favoritesService.removeAccommodation(accommodationId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Removed from saved accommodations"),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        await _favoritesService.saveAccommodation(
          accommodationId,
          accommodation,
          room,
          roomId,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Saved to favorites!"),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Refresh the UI
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
