import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:student_accomdation/core/routes.dart';

class LandlordProfileScreen extends StatelessWidget {
  LandlordProfileScreen({super.key});
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<DocumentSnapshot<Map<String, dynamic>>> getLandlordData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('User not logged in');
    }
    return FirebaseFirestore.instance.collection("landlords").doc(uid).get();
  }

  // Call this function when a landlord registers
  Future<void> createLandlordProfile(User user) async {
    await FirebaseFirestore.instance.collection("landlords").doc(user.uid).set({
      "landlordID": user.uid,
      "email": user.email ?? "",
      "name": user.displayName ?? "Landlord",
      "phoneNumber": "", // Initialize empty fields
      "accommodationName": "",
      "location": "",
      "profileImageUrl": "",
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: getLandlordData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text("Landlord Profile")),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    "Error loading profile",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // Retry loading data
                      // ignore: unused_local_variable
                      final newSnapshot = getLandlordData();
                      (context as Element).markNeedsBuild();
                    },
                    child: const Text("Retry"),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text("Landlord Profile")),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_outline,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    "Profile Not Found",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Your landlord profile doesn't exist yet",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        try {
                          await createLandlordProfile(user);
                          if (!context.mounted) return;
                          // Refresh the screen
                          (context as Element).markNeedsBuild();
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text("Error creating profile: $e")),
                          );
                        }
                      }
                    },
                    child: const Text("Create Profile"),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!.data()!;

        return Scaffold(
          appBar: AppBar(
            title: const Text("Landlord Profile",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  // Navigate to edit profile screen
                  _showEditProfileDialog(context, data);
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Image
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: data['profileImageUrl'] != null &&
                              data['profileImageUrl']!.isNotEmpty
                          ? NetworkImage(data['profileImageUrl']!)
                          : null,
                      child: data['profileImageUrl'] == null ||
                              data['profileImageUrl']!.isEmpty
                          ? const Icon(Icons.person,
                              size: 60, color: Colors.white)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A237E),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Profile Information
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileItem(
                          icon: Icons.person,
                          label: "Full Name",
                          value: data['name'] ?? "Not set",
                        ),
                        const Divider(),
                        _buildProfileItem(
                          icon: Icons.email,
                          label: "Email",
                          value: data['email'] ?? "Not set",
                        ),
                        const Divider(),
                        _buildProfileItem(
                          icon: Icons.phone,
                          label: "Phone Number",
                          value: data['phoneNumber']?.isNotEmpty == true
                              ? data['phoneNumber']!
                              : "Not set",
                        ),
                        const Divider(),
                        _buildProfileItem(
                          icon: Icons.business,
                          label: "Accommodation",
                          value: data['accommodationName']?.isNotEmpty == true
                              ? data['accommodationName']!
                              : "Not set",
                        ),
                        const Divider(),
                        _buildProfileItem(
                          icon: Icons.location_on,
                          label: "Location",
                          value: data['location']?.isNotEmpty == true
                              ? data['location']!
                              : "Not set",
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Statistics (if available)
                if (_hasAccommodationsData(data)) _buildStatisticsSection(data),

                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text("Edit Profile"),
                        onPressed: () {
                          _showEditProfileDialog(context, data);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.logout),
                        label: const Text("Logout"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          _confirmSignOut(context);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF1A237E)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection(Map<String, dynamic> data) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Statistics",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem("Properties", data['propertyCount'] ?? 0),
                _buildStatItem("Tenants", data['tenantCount'] ?? 0),
                _buildStatItem("Rating", data['rating'] ?? "N/A"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, dynamic value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A237E),
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  bool _hasAccommodationsData(Map<String, dynamic> data) {
    return data['propertyCount'] != null ||
        data['tenantCount'] != null ||
        data['rating'] != null;
  }

  void _showEditProfileDialog(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Profile"),
        content: const Text("Edit profile functionality coming soon!"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      await _auth.signOut();
      if (!context.mounted) return;

      // Navigate to login screen
      Navigator.of(context).pushNamedAndRemoveUntil(
        RouteManager.loginPage,
        (route) => false,
      );

      // Show success message (optional)
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Signed out successfully')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Sign Out'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _signOut(context);
              },
            ),
          ],
        );
      },
    );
  }
}
