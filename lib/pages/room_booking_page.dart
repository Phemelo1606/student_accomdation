import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:student_accomdation/pages/chatScreen.dart';
import 'package:student_accomdation/core/app_logger.dart';

class RoomBookingPage extends StatelessWidget {
  final Map<String, dynamic> room;
  final Map<String, dynamic> accommodation;
  final String roomId;

  const RoomBookingPage({
    super.key,
    required this.room,
    required this.accommodation,
    required this.roomId,
  });

  // Improved helper method to get landlord info
  Map<String, String> _getLandlordInfo() {
    // Try multiple possible field names for landlord ID
    String landlordId = accommodation['LandlordID'] ??
        accommodation['landlordID'] ??
        accommodation['landlord_id'] ??
        accommodation['ownerId'] ??
        accommodation['ownerID'] ??
        '';

    // If still empty, try from room data
    if (landlordId.isEmpty) {
      landlordId = room['LandlordID'] ??
          room['landlordID'] ??
          room['landlord_id'] ??
          room['ownerId'] ??
          room['ownerID'] ??
          '';
    }

    String landlordName = accommodation['name'] ??
        accommodation['Name'] ??
        accommodation['landlordName'] ??
        'Landlord';

    return {
      'LandlordID': landlordId.isEmpty ? 'unknown_landlord' : landlordId,
      'landlordName': landlordName,
    };
  }

  @override
  Widget build(BuildContext context) {
    final List<String> images = List<String>.from(room['Images'] ?? []);
    final List amenities = room['Amenities'] ?? [];
    final landlordInfo = _getLandlordInfo();

    return Scaffold(
      backgroundColor: const Color(0xFF1A168C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A168C),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "ACCOMMODATION",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Room image
                if (images.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      images.first,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),

                const SizedBox(height: 16),

                // Accommodation info
                Text(
                  accommodation['Name'] ?? "Unknown",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A168C),
                  ),
                ),
                Text(
                  accommodation['Location'] ?? "Unknown Location",
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Rent: R${room['MonthlyRent'] ?? 'N/A'}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A168C),
                  ),
                ),

                const SizedBox(height: 16),

                // Room details
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailItem(
                        "Room Number", room['RoomNumber'] ?? 'N/A'),
                    _buildDetailItem("Room Type", room['RoomType'] ?? 'N/A'),
                    _buildDetailItem(
                        "Capacity", "${room['Capacity'] ?? 'N/A'} persons"),
                    _buildDetailItem(
                        "Status", room['AvailabilityStatus'] ?? 'N/A'),
                  ],
                ),

                const SizedBox(height: 16),

                // Amenities
                const Text(
                  "Amenities:",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A168C),
                  ),
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: amenities.map<Widget>((amenity) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Color(0xFF1A168C), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            amenity.toString(),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _messageLandlord(context, landlordInfo);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "Message Landlord",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),

                // Blockchain lease info
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified_user, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Blockchain Lease Agreements",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                            Text(
                              "Secure digital leases with blockchain verification available in chat",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Debug button (optional - remove in production)
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () {
                      _showDebugInfo(context, landlordInfo);
                    },
                    child: const Text(
                      'Debug Chat Info',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Updated messageLandlord method to use enhanced chat
  void _messageLandlord(
      BuildContext context, Map<String, String> landlordInfo) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please log in to message the landlord"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate landlord ID
    if (landlordInfo['LandlordID'] == 'unknown_landlord') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Unable to identify landlord. Please try again later."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    AppLogger.log('🚀 Starting enhanced chat with:');
    AppLogger.log('   Student ID: ${currentUser.uid}');
    AppLogger.log('   Student Name: ${_getStudentName(currentUser)}');
    AppLogger.log('   Landlord ID: ${landlordInfo['LandlordID']}');
    AppLogger.log('   Landlord Name: ${landlordInfo['landlordName']}');

    // Navigate directly to the enhanced ChatScreen with blockchain lease support
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          landlordId: landlordInfo['LandlordID']!,
          landlordName: landlordInfo['landlordName']!,
          studentId: currentUser.uid,
          studentName: _getStudentName(currentUser),
        ),
      ),
    );
  }

  void _showDebugInfo(BuildContext context, Map<String, String> landlordInfo) {
    final currentUser = FirebaseAuth.instance.currentUser;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chat & Lease Info'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Student ID: ${currentUser?.uid ?? "Not logged in"}'),
              const SizedBox(height: 8),
              Text(
                  'Student Name: ${currentUser != null ? _getStudentName(currentUser) : "N/A"}'),
              const SizedBox(height: 8),
              Text('Landlord ID: ${landlordInfo['LandlordID']}'),
              const SizedBox(height: 8),
              Text('Landlord Name: ${landlordInfo['landlordName']}'),
              const SizedBox(height: 16),
              const Text(
                'Enhanced Chat Features:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text('• Blockchain lease agreements'),
              const Text('• IPFS document storage'),
              const Text('• Digital signatures'),
              const Text('• Immutable transaction records'),
              const SizedBox(height: 16),
              const Text(
                'If chat is not working, check:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text('1. Landlord ID exists in Firestore'),
              const Text('2. Chat collection rules allow read/write'),
              const Text('3. Both users are authenticated'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            "$label: ",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  String _getStudentName(User user) {
    // You might want to fetch this from Firestore user profile
    return user.displayName ?? user.email?.split('@').first ?? 'Student';
  }
}
