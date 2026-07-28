// lib/features/staff/housing_staff_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:student_accomdation/pages/accommodation_detail_screen.dart';

class HousingStaffScreen extends StatefulWidget {
  const HousingStaffScreen({super.key});

  @override
  State<HousingStaffScreen> createState() => _HousingStaffScreenState();
}

class _HousingStaffScreenState extends State<HousingStaffScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _selectedFilter = 'All';

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (!mounted) return;
      // Navigate to login screen or root
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showSignOutDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _signOut();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Housing Accreditation',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          // Filter dropdown
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'All', child: Text('All Accommodations')),
              const PopupMenuItem(
                  value: 'Pending', child: Text('Pending Review')),
              const PopupMenuItem(
                  value: 'Accredited', child: Text('Accredited')),
              const PopupMenuItem(value: 'Rejected', child: Text('Rejected')),
            ],
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Text('Filter'),
                  Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          // Sign out button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showSignOutDialog,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: _buildAccommodationsList(),
    );
  }

  Widget _buildAccommodationsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getAccommodationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final accommodations = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: accommodations.length,
          itemBuilder: (context, index) {
            final accommodation = accommodations[index];
            final data = accommodation.data() as Map<String, dynamic>? ??
                {}; // Added null safety
            final landlordId = accommodation.reference.parent.parent?.id ?? '';

            return _buildAccommodationCard(accommodation.id, data, landlordId);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getAccommodationsStream() {
    if (_selectedFilter == 'All') {
      return _firestore.collectionGroup('accommodations').snapshots();
    } else {
      return _firestore
          .collectionGroup('accommodations')
          .where('AccreditationStatus', isEqualTo: _selectedFilter)
          .snapshots();
    }
  }

  Widget _buildAccommodationCard(
      String accommodationId, Map<String, dynamic> data, String landlordId) {
    final status = data['AccreditationStatus'] ?? 'Pending';
    final statusColor = _getStatusColor(status);

    // FIX: Safely parse safetyRating to handle both String and number types
    final safetyRating = _parseSafetyRating(data['SafetyRating']);

    // FIX: Use proper null checks for all data fields
    final images = data['Images'] as List<dynamic>?;
    final firstImage =
        images != null && images.isNotEmpty ? images.first.toString() : null;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[200],
          ),
          child: firstImage != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    firstImage,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.apartment, color: Colors.grey[400]);
                    },
                  ),
                )
              : Icon(Icons.apartment, size: 30, color: Colors.grey[400]),
        ),
        title: Text(
          data['Name']?.toString() ?? 'Unnamed Accommodation',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['Location']?.toString() ?? 'No location'),
            if (data['LandlordName'] != null)
              Text('By: ${data['LandlordName']}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // FIX: Use the parsed safetyRating (now a double) for comparison
                if (safetyRating > 0)
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 16),
                      Text('${safetyRating.toStringAsFixed(1)}/5'),
                    ],
                  ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AccommodationDetailScreen(
                accommodationId: accommodationId,
                landlordId: landlordId,
                accommodationData: data,
              ),
            ),
          );
        },
      ),
    );
  }

  // NEW: Helper method to safely parse safety rating from various types
  double _parseSafetyRating(dynamic rating) {
    if (rating == null) return 0.0;

    if (rating is int) {
      return rating.toDouble();
    } else if (rating is double) {
      return rating;
    } else if (rating is String) {
      return double.tryParse(rating) ?? 0.0;
    } else {
      return 0.0;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Accredited':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      case 'Pending':
      default:
        return Colors.orange;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.apartment, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No Accommodations Found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'All'
                ? 'No accommodations have been submitted yet.'
                : 'No ${_selectedFilter.toLowerCase()} accommodations found.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
