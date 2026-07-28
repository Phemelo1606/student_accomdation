import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:student_accomdation/core/routes.dart';
import 'package:student_accomdation/features/maintenance/maintenance.dart';
import 'package:student_accomdation/core/app_logger.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late Future<Map<String, dynamic>> _profileDataFuture;
  Map<String, dynamic>? _currentRoom;
  final List<Map<String, dynamic>> _maintenanceRequests = [];
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _profileDataFuture = _loadProfileData();
  }

  Future<Map<String, dynamic>> _loadProfileData() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      AppLogger.log('🔍 Loading student profile data for: ${user.uid}');

      // Load student data
      final studentDoc =
          await _firestore.collection("users").doc(user.uid).get();
      if (!studentDoc.exists) {
        throw Exception('Student profile not found');
      }

      final studentData = studentDoc.data()!;
      AppLogger.log('✅ Student data loaded: ${studentData['Name']}');

      // Load current room
      final roomData = await _getCurrentRoom(user.uid);
      if (roomData != null) {
        AppLogger.log('✅ Room data loaded: ${roomData['roomDetails']?['RoomNumber']}');
      } else {
        AppLogger.log('ℹ️ No active room found');
      }

      // Load maintenance requests (with fallback for missing index)
      final maintenanceData = await _getMaintenanceRequests(user.uid);
      AppLogger.log('✅ Maintenance requests loaded: ${maintenanceData.length}');

      return {
        'student': studentData,
        'room': roomData,
        'maintenanceRequests': maintenanceData,
      };
    } catch (e) {
      AppLogger.log('❌ Error loading profile data: $e');
      throw Exception('Failed to load student data: $e');
    }
  }

  Future<Map<String, dynamic>?> _getCurrentRoom(String studentId) async {
    try {
      AppLogger.log('🔍 Fetching current room for student: $studentId');

      final roomDoc =
          await _firestore.collection('StudentRooms').doc(studentId).get();

      if (!roomDoc.exists) {
        AppLogger.log('❌ No StudentRooms document found');
        return null;
      }

      final roomData = roomDoc.data()!;

      // Check if room is active
      if (!(roomData['IsActive'] ?? false)) {
        AppLogger.log('ℹ️ Room is not active');
        return null;
      }

      final roomId = roomData['RoomID'] as String?;
      var accommodationId = roomData['AccommodationID'] as String?;

      AppLogger.log(
          '📋 Room details - RoomID: $roomId, AccommodationID: $accommodationId');
      AppLogger.log('🔍 Room Data Types:');
      AppLogger.log('   RoomID type: ${roomId.runtimeType}');
      AppLogger.log('   AccommodationID type: ${accommodationId.runtimeType}');

      // Validate required fields
      if (roomId == null || accommodationId == null) {
        AppLogger.log('❌ Missing RoomID or AccommodationID');
        return null;
      }

      Map<String, dynamic>? roomDetails;
      Map<String, dynamic>? accommodationDetails;

      // Get room details
      try {
        final roomDocSnapshot = await _firestore
            .collection('Accommodations')
            .doc(accommodationId)
            .collection('Rooms')
            .doc(roomId)
            .get();

        if (roomDocSnapshot.exists) {
          roomDetails = roomDocSnapshot.data();
          AppLogger.log('✅ Room details found');
        } else {
          AppLogger.log(
              '❌ Room document not found at path: Accommodations/$accommodationId/Rooms/$roomId');
        }
      } catch (e) {
        AppLogger.log('❌ Error fetching room details: $e');
      }

      // Get accommodation details with fallback
      try {
        final accommodationDoc = await _firestore
            .collection('Accommodations')
            .doc(accommodationId)
            .get();

        if (accommodationDoc.exists) {
          accommodationDetails = accommodationDoc.data();
          AppLogger.log(
              '✅ Accommodation details found: ${accommodationDetails?['Name']}');
        } else {
          AppLogger.log('❌ Accommodation document not found: $accommodationId');
          // Create fallback accommodation details
          accommodationDetails = {
            'Name': 'Default Accommodation',
            'Location': 'Location not specified',
          };
        }
      } catch (e) {
        AppLogger.log('❌ Error fetching accommodation details: $e');
        // Create fallback accommodation details
        accommodationDetails = {
          'Name': 'Default Accommodation',
          'Location': 'Location not specified',
        };
      }

      if (roomDetails != null) {
        return {
          ...roomData,
          'roomDetails': roomDetails,
          'accommodationDetails': accommodationDetails ?? {},
          'accommodationId': accommodationId,
          'roomId': roomId,
        };
      }

      AppLogger.log('❌ No room details available');
      return null;
    } catch (e) {
      AppLogger.log('❌ Error in _getCurrentRoom: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _getMaintenanceRequests(
      String studentId) async {
    try {
      // Try the composite index query first
      try {
        final querySnapshot = await _firestore
            .collection('MaintenanceRequests')
            .where('StudentID', isEqualTo: studentId) // String comparison
            .orderBy('CreatedAt', descending: true)
            .limit(10)
            .get();

        final requests = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();

        AppLogger.log('📋 Found ${requests.length} maintenance requests');
        return requests;
      } catch (e) {
        // Fallback: Simple query without ordering if index doesn't exist
        AppLogger.log('⚠️ Composite index not available, using fallback query');
        final querySnapshot = await _firestore
            .collection('MaintenanceRequests')
            .where('StudentID', isEqualTo: studentId) // String comparison
            .limit(10)
            .get();

        final requests = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();

        // Sort manually by CreatedAt if available
        requests.sort((a, b) {
          final aDate = a['CreatedAt'];
          final bDate = b['CreatedAt'];
          if (aDate is Timestamp && bDate is Timestamp) {
            return bDate.compareTo(aDate);
          }
          return 0;
        });

        AppLogger.log('📋 Found ${requests.length} maintenance requests (fallback)');
        return requests;
      }
    } catch (e) {
      AppLogger.log('❌ Error fetching maintenance requests: $e');
      return [];
    }
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      await _profileDataFuture;
      setState(() {
        _profileDataFuture = _loadProfileData();
      });
    } finally {
      setState(() {
        _isRefreshing = false;
      });
    }
  }

  void _submitMaintenanceRequest() {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to submit maintenance requests'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_currentRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No active room found. Please wait until your lease is signed.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Get accommodation ID as string
    final accommodationId =
        _currentRoom!['accommodationId'] ?? _currentRoom!['AccommodationID'];

    if (accommodationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to find accommodation information.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    AppLogger.log('🔍 Submitting maintenance request with:');
    AppLogger.log('   RoomID: ${_currentRoom!['RoomID']}');
    AppLogger.log('   StudentID: ${user.uid}');
    AppLogger.log('   AccommodationID: $accommodationId');

    showDialog(
      context: context,
      builder: (context) => MaintenanceRequestDialog(
        roomId: _currentRoom!['RoomID'],
        studentId: user.uid,
        accommodationId: accommodationId,
        onSubmitted: () {
          _refreshData();
        },
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      await _auth.signOut();
      if (!mounted) return;

      // Navigate to login screen
      Navigator.of(context).pushNamedAndRemoveUntil(
        RouteManager.loginPage,
        (route) => false,
      );

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Signed out successfully'),
          backgroundColor: Colors.green,
        ),
      );
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

  Future<void> _confirmSignOut() async {
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
              onPressed: () => Navigator.of(context).pop(),
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

  Widget _buildProfileField(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: Colors.grey),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomSection(Map<String, dynamic>? room) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.meeting_room, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Text(
                  "My Room",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (room == null) _buildNoRoomState() else _buildRoomDetails(room),
          ],
        ),
      ),
    );
  }

  Widget _buildNoRoomState() {
    return Column(
      children: [
        Icon(Icons.meeting_room_outlined, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text(
          "No Active Room",
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Your room will appear here after you sign a lease agreement with a landlord",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500], fontSize: 14),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _refreshData,
          icon: const Icon(Icons.refresh),
          label: const Text('Check Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A237E),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildRoomDetails(Map<String, dynamic> room) {
    final roomDetails = room['roomDetails'] ?? {};
    final accommodationDetails = room['accommodationDetails'] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Accommodation Info
        if (accommodationDetails.isNotEmpty) ...[
          Text(
            accommodationDetails['Name'] ?? 'Accommodation',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),
          const SizedBox(height: 4),
          if (accommodationDetails['Location'] != null)
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  accommodationDetails['Location']!,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          const SizedBox(height: 16),
        ],

        // Room Details Grid - FIXED OVERFLOW
        SizedBox(
          height: 140, // Fixed height to prevent overflow
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.5, // Adjusted aspect ratio
            crossAxisSpacing: 12,
            mainAxisSpacing: 8,
            padding: EdgeInsets.zero,
            children: [
              _buildRoomDetailCard(
                  'Room Number',
                  roomDetails['RoomNumber']?.toString() ?? 'N/A',
                  Icons.numbers),
              _buildRoomDetailCard(
                  'Room Type', roomDetails['RoomType'] ?? 'N/A', Icons.room),
              _buildRoomDetailCard(
                  'Monthly Rent',
                  'R${roomDetails['MonthlyRent']?.toStringAsFixed(2) ?? 'N/A'}',
                  Icons.attach_money),
              _buildRoomDetailCard(
                  'Capacity',
                  '${roomDetails['Capacity']?.toString() ?? 'N/A'} person(s)',
                  Icons.people),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Lease Info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green[100]!),
          ),
          child: Row(
            children: [
              Icon(Icons.verified, color: Colors.green[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lease Active',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    Text(
                      'Started: ${_formatDate(room['LeaseStartDate'])}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Maintenance Request Button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _submitMaintenanceRequest,
            icon: const Icon(Icons.build, size: 20),
            label: const Text('Submit Maintenance Request'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(0xFF1A237E),
            ),
          ),
        ),
      ],
    );
  }

  // FIXED: Room detail card with better layout to prevent overflow
  Widget _buildRoomDetailCard(String label, String value, IconData icon) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceSection(List<Map<String, dynamic>> requests) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Text(
                  "Maintenance Requests",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const Spacer(),
                if (requests.isNotEmpty)
                  Text(
                    '${requests.length}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (requests.isEmpty)
              _buildNoMaintenanceState()
            else
              _buildMaintenanceList(requests),
          ],
        ),
      ),
    );
  }

  Widget _buildNoMaintenanceState() {
    return Column(
      children: [
        Icon(Icons.list_alt, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text(
          "No Maintenance Requests",
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Submit your first maintenance request using the button above",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500], fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildMaintenanceList(List<Map<String, dynamic>> requests) {
    return Column(
      children: [
        ...requests.map((request) => _buildMaintenanceRequestItem(request)),
        if (requests.length >= 10)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Showing latest 10 requests',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMaintenanceRequestItem(Map<String, dynamic> request) {
    final status = request['Status'] ?? 'Pending';
    final statusColor = _getStatusColor(status);
    final imageUrls = request['imageUrls'] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    request['RequestType'] ?? 'Maintenance Request',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              request['Description'] ?? 'No description provided',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),

            // Display attached images if any
            if (imageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Attached Images (${imageUrls.length})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: imageUrls.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrls[index],
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 80,
                              height: 80,
                              color: Colors.grey[200],
                              child: const Icon(Icons.broken_image),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Submitted: ${_formatDate(request['CreatedAt'])}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const Spacer(),
                if (request['UpdatedAt'] != null &&
                    request['UpdatedAt'] != request['CreatedAt'])
                  Text(
                    'Updated: ${_formatDate(request['UpdatedAt'])}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      final DateTime date = timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.parse(timestamp.toString());
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
            const SizedBox(height: 20),
            Text(
              'Error Loading Profile',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading your profile...'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Student Profile",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
            onPressed: _isRefreshing ? null : _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Sign Out",
            onPressed: _confirmSignOut,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _profileDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            if (!snapshot.hasData) {
              return _buildErrorState('No data available');
            }

            final data = snapshot.data!;
            final student = data['student'];
            final room = data['room'];
            final maintenanceRequests = data['maintenanceRequests'] ?? [];

            // Store room data for maintenance requests
            _currentRoom = room;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Profile Header
                  _buildProfileHeader(student),
                  const SizedBox(height: 24),

                  // Profile Details
                  _buildProfileDetails(student),
                  const SizedBox(height: 24),

                  // Room Section
                  _buildRoomSection(room),
                  const SizedBox(height: 24),

                  // Maintenance Requests Section
                  _buildMaintenanceSection(maintenanceRequests),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> student) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: student['profileImageUrl'] != null &&
                          student['profileImageUrl'].isNotEmpty
                      ? NetworkImage(student['profileImageUrl'])
                      : null,
                  backgroundColor: Colors.blue.shade100,
                  child: student['profileImageUrl'] == null ||
                          student['profileImageUrl'].isEmpty
                      ? const Icon(Icons.person, size: 60, color: Colors.white)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.school,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              student['Name'] ?? 'No Name',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              student['StudentEmail'] ?? 'No Email',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileDetails(Map<String, dynamic> student) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildProfileField(
              'Student Number',
              student['StudentID'] ?? 'Not provided',
              icon: Icons.badge,
            ),
            const Divider(),
            _buildProfileField(
              'Faculty',
              student['Faculty'] ?? 'Not provided',
              icon: Icons.school,
            ),
            const Divider(),
            _buildProfileField(
              'Year of Study',
              student['YearOfStudy']?.toString() ?? 'Not provided',
              icon: Icons.calendar_today,
            ),
          ],
        ),
      ),
    );
  }
}

// SINGLE IMPLEMENTATION: Maintenance Request Dialog
