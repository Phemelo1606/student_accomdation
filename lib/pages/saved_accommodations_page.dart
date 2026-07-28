// pages/saved_accommodations_page.dart
import 'package:flutter/material.dart';
import 'package:student_accomdation/services/favorites_service.dart';
import 'package:student_accomdation/pages/room_booking_page.dart';

class SavedAccommodationsPage extends StatefulWidget {
  const SavedAccommodationsPage({super.key});

  @override
  State<SavedAccommodationsPage> createState() =>
      _SavedAccommodationsPageState();
}

class _SavedAccommodationsPageState extends State<SavedAccommodationsPage> {
  final FavoritesService _favoritesService = FavoritesService();
  late Stream<List<Map<String, dynamic>>> _favoritesStream;

  @override
  void initState() {
    super.initState();
    _favoritesStream = _favoritesService.getSavedAccommodations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A168C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A168C),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "SAVED ACCOMMODATIONS",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _favoritesStream,
          builder: (context, snapshot) {
            // Handle connection state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            // Handle errors
            if (snapshot.hasError) {
              debugPrint('Stream error: ${snapshot.error}');
              return _buildErrorState("Error loading saved accommodations");
            }

            // Handle data
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState();
            }

            final favorites = snapshot.data!;
            return _buildFavoritesList(favorites);
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A168C)),
      ),
    );
  }

  Widget _buildFavoritesList(List<Map<String, dynamic>> favorites) {
    return Column(
      children: [
        // Saved count header
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.favorite, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text(
                '${favorites.length} saved accommodation${favorites.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
            ],
          ),
        ),

        // Favorites list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshFavorites,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final favorite = favorites[index];
                final accommodationData = favorite['accommodationData'] ?? {};
                final roomData = favorite['roomData'] ?? {};
                final roomId = favorite['roomId'] ?? '';
                final accommodationId = favorite['accommodationId'] ?? '';

                return _buildFavoriteCard(
                  context,
                  accommodationData,
                  roomData,
                  roomId,
                  accommodationId,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            const Text(
              "No Saved Accommodations",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Save accommodations you like by tapping the heart icon on room cards",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A168C),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.search, color: Colors.white),
              label: const Text(
                "Browse Accommodations",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 24),
            Text(
              "Something went wrong",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshFavorites,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A168C),
              ),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                "Try Again",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteCard(
    BuildContext context,
    Map<String, dynamic> accommodation,
    Map<String, dynamic> room,
    String roomId,
    String accommodationId,
  ) {
    final List<String> images = List<String>.from(room['Images'] ?? []);
    final String accommodationName =
        accommodation["Name"] ?? "Unknown Accommodation";
    final String accommodationLocation =
        accommodation["Location"] ?? "Location not specified";
    final double monthlyRent = (room['MonthlyRent'] ?? 0).toDouble();
    final List<dynamic> amenities = room['Amenities'] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with accommodation info and remove button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.favorite,
                              color: Colors.red, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              accommodationName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A237E),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              accommodationLocation,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 24),
                  onPressed: () => _removeFavorite(accommodationId),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Room image with better error handling
            if (images.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  images.first,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 140,
                      width: double.infinity,
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF1A168C)),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 140,
                      width: double.infinity,
                      color: Colors.grey.shade200,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image,
                              color: Colors.grey, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            "No image available",
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 12),

            // Room details header
            Row(
              children: [
                Text(
                  "Room ${room['RoomNumber'] ?? 'N/A'}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A237E),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

            // Price and details
            Row(
              children: [
                _buildPriceTag(monthlyRent),
                const SizedBox(width: 16),
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    children: [
                      _buildDetailItem(
                          Icons.category, room['RoomType'] ?? 'N/A'),
                      _buildDetailItem(
                          Icons.people, "${room['Capacity'] ?? 'N/A'} persons"),
                    ],
                  ),
                ),
              ],
            ),

            // Description
            if (room['Description'] != null && room['Description'].isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    room['Description'],
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),

            // Amenities preview
            if (amenities.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: amenities.take(3).map((amenity) {
                      return Chip(
                        label: Text(
                          amenity.toString(),
                          style: const TextStyle(fontSize: 11),
                        ),
                        backgroundColor: Colors.blue.shade50,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                  if (amenities.length > 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "+ ${amenities.length - 3} more amenities",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _removeFavorite(accommodationId),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 18),
                    label: const Text(
                      "Remove",
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
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
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD600),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.roofing,
                        color: Colors.black, size: 18),
                    label: const Text(
                      "Book Now",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceTag(double price) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        "R${price.toStringAsFixed(0)}/month",
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
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

  Future<void> _refreshFavorites() async {
    setState(() {
      _favoritesStream = _favoritesService.getSavedAccommodations();
    });
  }

  Future<void> _removeFavorite(String accommodationId) async {
    try {
      await _favoritesService.removeAccommodation(accommodationId);
      if (!mounted) return;
      // The StreamBuilder will automatically update when the stream emits new data
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Removed from saved accommodations"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error removing favorite: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
