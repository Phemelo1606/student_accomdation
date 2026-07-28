import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:student_accomdation/pages/addAccommodations.dart';
import 'package:student_accomdation/pages/landlordProfile.dart';
import 'package:student_accomdation/pages/landlord_messages_screen.dart';
import 'package:student_accomdation/pages/manage_property.dart';

class LandlordHomePage extends StatefulWidget {
  const LandlordHomePage({super.key});

  @override
  State<LandlordHomePage> createState() => _LandlordHomePageState();
}

class _LandlordHomePageState extends State<LandlordHomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _ensureLandlordDocumentExists() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final landlordDoc =
        await _firestore.collection("landlords").doc(user.uid).get();

    if (!landlordDoc.exists) {
      // Create the landlord document if it doesn't exist
      await _firestore.collection("landlords").doc(user.uid).set({
        "landlordID": user.uid,
        "email": user.email ?? "",
        "name": user.displayName ?? "Landlord",
        "phoneNumber": "",
        "accommodationName": "",
        "location": "",
        "profileImageUrl": "",
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Ensure landlord document exists when the page loads
    _ensureLandlordDocumentExists();
  }

  @override
  Widget build(BuildContext context) {
    final String landlordId = _auth.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF1A168C),
      body: SafeArea(
        child: Column(
          children: [
            // Header with Search Bar
            _buildHeaderSection(landlordId),

            // White Content Area
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
                child: _buildAccommodationsList(landlordId),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(landlordId),
    );
  }

  Widget _buildHeaderSection(String landlordId) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Message
          StreamBuilder<DocumentSnapshot>(
            stream:
                _firestore.collection("landlords").doc(landlordId).snapshots(),
            builder: (context, snapshot) {
              final landlordName = snapshot.hasData && snapshot.data!.exists
                  ? ((snapshot.data!.data() as Map<String, dynamic>)['name'] ??
                      "Landlord")
                  : "Landlord";

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  "Welcome, $landlordName!",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),

          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search your properties...",
                      border: InputBorder.none,
                      icon: Icon(Icons.search, color: Colors.grey),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    // Show filter options
                    _showFilterOptions(context);
                  },
                  icon: const Icon(Icons.filter_list, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccommodationsList(String landlordId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection("landlords")
          .doc(landlordId)
          .collection("accommodations")
          .orderBy("createdAt", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A168C)),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final accommodations = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: accommodations.length,
          itemBuilder: (context, index) {
            final accommodation = accommodations[index];
            final data = accommodation.data() as Map<String, dynamic>;

            return _buildPropertyCard(
              context,
              accommodationData: data,
              accommodationId: accommodation.id,
              landlordId: landlordId,
            );
          },
        );
      },
    );
  }

  Widget _buildPropertyCard(
    BuildContext context, {
    required Map<String, dynamic> accommodationData,
    required String accommodationId,
    required String landlordId,
  }) {
    // FIX: Proper type-safe data extraction
    final title = accommodationData["Name"]?.toString() ?? "Untitled";
    final location =
        accommodationData["Location"]?.toString() ?? "Unknown Location";
    final capacity = accommodationData["Capacity"] is int
        ? (accommodationData["Capacity"] as int).toString()
        : accommodationData["Capacity"]?.toString() ?? "0";
    final distance = accommodationData["DistanceFromCampus"] is double
        ? (accommodationData["DistanceFromCampus"] as double).toStringAsFixed(1)
        : accommodationData["DistanceFromCampus"]?.toString() ?? "0.0";
    final type = accommodationData["Type"]?.toString() ?? "Unknown type";
    final accreditation =
        accommodationData["AccreditationStatus"]?.toString() ?? "Pending";

    // FIX: Handle safety rating properly - it's stored as int
    final safetyRating = accommodationData["SafetyRating"] is int
        ? (accommodationData["SafetyRating"] as int)
        : 0;

    // Get status color based on accreditation
    final statusColor = _getStatusColor(accreditation);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Row with Status Badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A168C),
                    ),
                  ),
                ),
                // Accreditation Status Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    accreditation.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Location
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    style: const TextStyle(color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Property Details
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _buildDetailItem(Icons.people, "Capacity", "$capacity people"),
                _buildDetailItem(
                    Icons.directions_walk, "Distance", "${distance}km"),
                _buildDetailItem(Icons.security, "Safety",
                    safetyRating > 0 ? "$safetyRating/5" : "Not rated"),
                _buildDetailItem(Icons.category, "Type", type),
              ],
            ),
            const SizedBox(height: 16),

            // Safety Rating Stars (if rated)
            if (safetyRating > 0) ...[
              Row(
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    "Safety Rating: ${'⭐' * safetyRating}",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // View details action
                      _showPropertyDetails(context, title, location,
                          accreditation, safetyRating);
                    },
                    child: const Text("View Details"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A168C),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ManagePropertyPage(
                            accommodationId: accommodationId,
                            landlordId: landlordId,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      "Manage",
                      style: TextStyle(color: Colors.white),
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

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF1A168C)),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              "Error Loading Properties",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A168C),
              ),
              child: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.home_work_outlined,
              size: 100,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            const Text(
              "No Accommodations Yet",
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Get started by adding your first property",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddAccommodationPage(
                        landlordId: _auth.currentUser!.uid),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A168C),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: const Text(
                "Add First Property",
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BottomNavigationBar _buildBottomNavigationBar(String landlordId) {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFF1A168C),
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white70,
      type: BottomNavigationBarType.fixed,
      currentIndex: 0, // Home is selected
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: "Home",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_business),
          label: "Add",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.message),
          label: "Messages",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: "Profile",
        ),
      ],
      onTap: (index) {
        _onBottomNavItemTapped(index, landlordId);
      },
    );
  }

  void _onBottomNavItemTapped(int index, String landlordId) {
    switch (index) {
      case 0:
        // Already on home page
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddAccommodationPage(landlordId: landlordId),
          ),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LandlordMessagesScreen(
              landlordId: landlordId,
              landlordName: _auth.currentUser?.displayName ?? "Landlord",
            ),
          ),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LandlordProfileScreen(),
          ),
        );
        break;
    }
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Filter Properties",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // Add filter options here
              ListTile(
                leading: const Icon(Icons.sort),
                title: const Text("Sort by Date"),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.filter_alt),
                title: const Text("Filter by Type"),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPropertyDetails(BuildContext context, String title, String location,
      String accreditation, int safetyRating) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Location: $location"),
            const SizedBox(height: 8),
            Text("Accreditation: $accreditation"),
            const SizedBox(height: 8),
            Text(
                "Safety Rating: ${safetyRating > 0 ? '$safetyRating/5' : 'Not rated'}"),
            const SizedBox(height: 8),
            const Text("Property details coming soon..."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}
