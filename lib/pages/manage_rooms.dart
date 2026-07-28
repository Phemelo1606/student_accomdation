// manage_rooms_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:student_accomdation/core/app_logger.dart';

class ManageRoomsPage extends StatefulWidget {
  final String accommodationId;
  final String landlordId;

  const ManageRoomsPage({
    super.key,
    required this.accommodationId,
    required this.landlordId,
  });

  @override
  _ManageRoomsPageState createState() => _ManageRoomsPageState();
}

class _ManageRoomsPageState extends State<ManageRoomsPage> {
  final TextEditingController _roomNumberController = TextEditingController();
  final TextEditingController _monthlyRentController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isLoading = false;
  bool _showAddForm = false;
  String? _editingRoomId;
  int _currentTabIndex = 0; // 0 for Rooms, 1 for Maintenance

  // Room fields
  String _availabilityStatus = "Available";
  String _roomType = "Single";
  List<String> _roomAmenities = [];
  List<String> _roomImages = []; // Store image URLs
  final List<File> _selectedImages = []; // Store selected images for upload

  final ImagePicker _imagePicker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final List<String> _availabilityOptions = [
    "Available",
    "Occupied",
    "Under Maintenance",
    "Reserved"
  ];

  final List<String> _roomTypeOptions = [
    "Single",
    "Double",
    "Shared",
    "Studio",
    "Suite"
  ];

  final List<String> _amenityOptions = [
    "WiFi",
    "Air Conditioning",
    "Heating",
    "Private Bathroom",
    "Shared Bathroom",
    "Kitchen Access",
    "Laundry",
    "Cleaning Service",
    "Study Desk",
    "Wardrobe",
    "Balcony",
    "TV",
    "Refrigerator",
    "Microwave",
    "Hotplate",
    "Kettle",
    "Toaster",
    "En-suite",
    "Desk Lamp",
    "Bookshelf",
    "Cupboard",
    "Drawers",
    "Bedside Table",
    "Lamp",
    "Fan",
    "Heater",
    "Security Safe",
    "Mirror",
    "Curtains",
    "Carpet",
    "Tiled Floor",
    "Parking",
    "Garden Access",
    "Swimming Pool",
    "Gym Access",
    "Study Area",
    "Common Room",
    "Bicycle Storage"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Rooms",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A237E),
        actions: [
          if (_currentTabIndex == 0) // Only show add button in Rooms tab
            IconButton(
              icon: Icon(_showAddForm ? Icons.close : Icons.add),
              onPressed: _toggleAddForm,
              tooltip: _showAddForm ? "Close Form" : "Add Room",
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Tab Bar
                _buildTabBar(),
                // Content
                Expanded(
                  child: _currentTabIndex == 0
                      ? _showAddForm
                          ? _buildRoomForm() // Full screen form when visible
                          : _buildRoomsList() // Full screen list when form hidden
                      : _buildMaintenanceSection(), // Maintenance requests
                ),
              ],
            ),
      // Add Floating Action Button for better UX (only in Rooms tab)
      floatingActionButton: _currentTabIndex == 0 && !_showAddForm
          ? FloatingActionButton(
              onPressed: _toggleAddForm,
              backgroundColor: const Color(0xFF1A237E),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          _buildTabButton(0, 'Rooms', Icons.meeting_room),
          _buildTabButton(1, 'Maintenance', Icons.build),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String title, IconData icon) {
    final isSelected = _currentTabIndex == index;
    return Expanded(
      child: Material(
        color: isSelected ? Colors.white : Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _currentTabIndex = index;
              _showAddForm = false;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 20,
                    color: isSelected
                        ? const Color(0xFF1A237E)
                        : Colors.grey[600]),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color:
                        isSelected ? const Color(0xFF1A237E) : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========== MAINTENANCE REQUESTS SECTION ==========

  Widget _buildMaintenanceSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('MaintenanceRequests')
          .where('AccommodationID',
              isEqualTo: widget.accommodationId) // Use string directly
          .orderBy('CreatedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        AppLogger.log('🔍 Landlord Maintenance Query:');
        AppLogger.log('   AccommodationID: ${widget.accommodationId}');
        AppLogger.log('   Has data: ${snapshot.hasData}');
        AppLogger.log('   Number of requests: ${snapshot.data?.docs.length ?? 0}');
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            AppLogger.log(
                '   Request: ${data['RequestType']} - AccommodationID: ${data['AccommodationID']}');
          }
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoMaintenanceRequests();
        }

        final requests = snapshot.data!.docs;

        // Group requests by status
        final pendingRequests = requests.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['Status'] == 'Pending';
        }).toList();

        final inProgressRequests = requests.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['Status'] == 'In Progress';
        }).toList();

        final completedRequests = requests.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['Status'] == 'Completed';
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Statistics Cards
              _buildMaintenanceStats(pendingRequests.length,
                  inProgressRequests.length, completedRequests.length),
              const SizedBox(height: 20),

              // Pending Requests
              if (pendingRequests.isNotEmpty) ...[
                _buildRequestSection('Pending Requests', pendingRequests,
                    Colors.orange, Icons.pending_actions),
                const SizedBox(height: 20),
              ],

              // In Progress Requests
              if (inProgressRequests.isNotEmpty) ...[
                _buildRequestSection('In Progress', inProgressRequests,
                    Colors.blue, Icons.build_circle),
                const SizedBox(height: 20),
              ],

              // Completed Requests
              if (completedRequests.isNotEmpty) ...[
                _buildRequestSection('Completed', completedRequests,
                    Colors.green, Icons.check_circle),
                const SizedBox(height: 20),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMaintenanceStats(int pending, int inProgress, int completed) {
    return Row(
      children: [
        Expanded(
          child:
              _buildStatCard('Pending', pending, Colors.orange, Icons.pending),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
              'In Progress', inProgress, Colors.blue, Icons.build),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              _buildStatCard('Completed', completed, Colors.green, Icons.check),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, int count, Color color, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestSection(String title,
      List<QueryDocumentSnapshot> requests, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                requests.length.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...requests.map((request) => _buildMaintenanceRequestCard(request)),
      ],
    );
  }

  Widget _buildMaintenanceRequestCard(QueryDocumentSnapshot requestDoc) {
    final request = requestDoc.data() as Map<String, dynamic>;
    final status = request['Status'] ?? 'Pending';
    final statusColor = _getMaintenanceStatusColor(status);
    final imageUrls = request['imageUrls'] ?? [];
    final roomId = request['RoomID']?.toString() ?? 'Unknown Room';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Request Type and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['RequestType'] ?? 'Maintenance Request',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Room: $roomId',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
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

            // Description
            Text(
              request['Description'] ?? 'No description provided',
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),

            // Student Information
            if (request['StudentID'] != null) ...[
              const SizedBox(height: 8),
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('Students')
                    .doc(request['StudentID'].toString())
                    .get(),
                builder: (context, studentSnapshot) {
                  if (studentSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Text(
                      'Loading student info...',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    );
                  }

                  if (studentSnapshot.hasData && studentSnapshot.data!.exists) {
                    final studentData =
                        studentSnapshot.data!.data() as Map<String, dynamic>;
                    return Text(
                      'Student: ${studentData['Name'] ?? 'Unknown'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    );
                  }

                  return Text(
                    'Student ID: ${request['StudentID']}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  );
                },
              ),
            ],

            // Attached Images
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

            // Dates
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
                if (request['UpdatedAt'] != null)
                  Text(
                    'Updated: ${_formatDate(request['UpdatedAt'])}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),

            // Action Buttons based on status
            const SizedBox(height: 12),
            _buildMaintenanceActions(requestDoc.id, status),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceActions(String requestId, String currentStatus) {
    return Row(
      children: [
        if (currentStatus == 'Pending') ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _updateRequestStatus(requestId, 'In Progress'),
              icon: const Icon(Icons.build, size: 16),
              label: const Text('Start Work'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _updateRequestStatus(requestId, 'Completed'),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Mark Complete'),
            ),
          ),
        ] else if (currentStatus == 'In Progress') ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _updateRequestStatus(requestId, 'Completed'),
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Mark Complete'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _updateRequestStatus(requestId, 'Pending'),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Reopen'),
            ),
          ),
        ] else if (currentStatus == 'Completed') ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _updateRequestStatus(requestId, 'In Progress'),
              icon: const Icon(Icons.build, size: 16),
              label: const Text('Reopen'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _deleteMaintenanceRequest(requestId),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.delete, size: 16),
              label: const Text('Clear'),
            ),
          ),
        ],
      ],
    );
  }

  Color _getMaintenanceStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _updateRequestStatus(String requestId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('MaintenanceRequests')
          .doc(requestId)
          .update({
        'Status': newStatus,
        'UpdatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request marked as $newStatus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteMaintenanceRequest(String requestId) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Maintenance Request'),
        content: const Text(
            'Are you sure you want to clear this completed maintenance request? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('MaintenanceRequests')
            .doc(requestId)
            .delete();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maintenance request cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildNoMaintenanceRequests() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.build, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'No Maintenance Requests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Maintenance requests from students will appear here for your review and action.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      final DateTime date = timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.parse(timestamp.toString());
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }

  // ========== EXISTING ROOM MANAGEMENT CODE ==========

  Widget _buildRoomsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("Accommodations")
          .doc(widget.accommodationId)
          .collection("Rooms")
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final rooms = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index].data() as Map<String, dynamic>;
            return _buildRoomCard(rooms[index].id, room);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.meeting_room, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 24),
          const Text(
            "No Rooms Added",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Get started by adding your first room",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _toggleAddForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              "Add First Room",
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleAddForm() {
    setState(() {
      _showAddForm = !_showAddForm;
      if (!_showAddForm) {
        _editingRoomId = null;
        _clearForm();
      }
    });
  }

  Widget _buildRoomForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _editingRoomId == null ? "Add New Room" : "Edit Room",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
              if (_editingRoomId != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _cancelEdit,
                  tooltip: "Cancel Edit",
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Room Images Section
          _buildImageUploadSection(),
          const SizedBox(height: 16),

          // Room Number
          TextFormField(
            controller: _roomNumberController,
            decoration: const InputDecoration(
              labelText: "Room Number*",
              border: OutlineInputBorder(),
              hintText: "e.g., 101, A1, Ground Floor",
            ),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 12),

          // Room Type
          DropdownButtonFormField<String>(
            initialValue: _roomType,
            decoration: const InputDecoration(
              labelText: "Room Type*",
              border: OutlineInputBorder(),
            ),
            items: _roomTypeOptions.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (value) => setState(() => _roomType = value!),
          ),
          const SizedBox(height: 12),

          // Monthly Rent
          TextFormField(
            controller: _monthlyRentController,
            decoration: const InputDecoration(
              labelText: "Monthly Rent (R)*",
              border: OutlineInputBorder(),
              hintText: "e.g., 500",
              prefixText: "R ",
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),

          // Capacity
          TextFormField(
            controller: _capacityController,
            decoration: const InputDecoration(
              labelText: "Capacity (persons)*",
              border: OutlineInputBorder(),
              hintText: "e.g., 2",
              suffixText: "persons",
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),

          // Availability Status
          DropdownButtonFormField<String>(
            initialValue: _availabilityStatus,
            decoration: const InputDecoration(
              labelText: "Availability Status*",
              border: OutlineInputBorder(),
            ),
            items: _availabilityOptions.map((status) {
              return DropdownMenuItem(
                value: status,
                child: Text(status),
              );
            }).toList(),
            onChanged: (value) => setState(() => _availabilityStatus = value!),
          ),
          const SizedBox(height: 12),

          // Description
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: "Room Description",
              border: OutlineInputBorder(),
              hintText: "Describe the room features, view, etc...",
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // Amenities
          const Text(
            "Amenities:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildAmenitiesSection(),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveRoom,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    _editingRoomId == null ? "Add Room" : "Update Room",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (_editingRoomId != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancelEdit,
                    child: const Text("Cancel"),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20), // Extra bottom padding
        ],
      ),
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Room Photos",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A237E),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Add photos of the room to attract more students",
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),

        // Image Grid
        if (_roomImages.isNotEmpty || _selectedImages.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _roomImages.length + _selectedImages.length,
            itemBuilder: (context, index) {
              if (index < _roomImages.length) {
                // Existing images from Firestore
                return _buildImageItem(_roomImages[index], isExisting: true);
              } else {
                // Newly selected images
                final fileIndex = index - _roomImages.length;
                return _buildImageItem(_selectedImages[fileIndex],
                    isExisting: false);
              }
            },
          ),

        const SizedBox(height: 12),

        // Add Image Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickImageFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text("Gallery"),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _takePhotoWithCamera,
                icon: const Icon(Icons.camera_alt),
                label: const Text("Camera"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImageItem(dynamic image, {required bool isExisting}) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: isExisting
                ? Image.network(
                    image as String,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        child:
                            const Icon(Icons.broken_image, color: Colors.grey),
                      );
                    },
                  )
                : Image.file(
                    image as File,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeImage(image, isExisting: isExisting),
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(4),
              child: const Icon(
                Icons.close,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (!mounted) return;
      setState(() {
        _selectedImages
            .addAll(images.map((xfile) => File(xfile.path)).toList());
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error picking images: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takePhotoWithCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (!mounted) return;
      if (image != null) {
        setState(() {
          _selectedImages.add(File(image.path));
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error taking photo: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeImage(dynamic image, {required bool isExisting}) {
    setState(() {
      if (isExisting) {
        _roomImages.remove(image as String);
      } else {
        _selectedImages.remove(image as File);
      }
    });
  }

  Future<List<String>> _uploadImages(String roomId) async {
    List<String> uploadedUrls = [];

    for (int i = 0; i < _selectedImages.length; i++) {
      try {
        final file = _selectedImages[i];
        final fileName =
            'room_${roomId}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

        // ✅ Correct: only use relative path
        final ref = _storage
            .ref()
            .child('room_images/${widget.accommodationId}/$fileName');

        // Upload the file
        await ref.putFile(file);

        // Get the download URL
        final url = await ref.getDownloadURL();
        uploadedUrls.add(url);
      } catch (e) {
        AppLogger.log('Error uploading image $i: $e');
      }
    }

    return uploadedUrls;
  }

  Widget _buildAmenitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Select Amenities:",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A237E),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Choose the amenities available in this room",
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),

        // Amenities Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 3,
          ),
          itemCount: _amenityOptions.length,
          itemBuilder: (context, index) {
            final amenity = _amenityOptions[index];
            final isSelected = _roomAmenities.contains(amenity);

            return Card(
              elevation: isSelected ? 2 : 0,
              color: isSelected
                  ? const Color(0xFF1A237E).withOpacity(0.1)
                  : Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF1A237E)
                      : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _roomAmenities.remove(amenity);
                    } else {
                      _roomAmenities.add(amenity);
                    }
                  });
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color:
                            isSelected ? const Color(0xFF1A237E) : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          amenity,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFF1A237E)
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // Selected amenities summary
        if (_roomAmenities.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            "Selected Amenities:",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _roomAmenities.map((amenity) {
              return Chip(
                label: Text(amenity),
                backgroundColor: const Color(0xFF1A237E).withOpacity(0.1),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () {
                  setState(() {
                    _roomAmenities.remove(amenity);
                  });
                },
              );
            }).toList(),
          ),
        ] else ...[
          const SizedBox(height: 16),
          Text(
            "No amenities selected",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRoomCard(String roomId, Map<String, dynamic> room) {
    final List<String> images = List<String>.from(room['Images'] ?? []);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Room Images
            if (images.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        return Container(
                          width: 160,
                          margin: EdgeInsets.only(right: 8, bottom: 8),
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
                  const SizedBox(height: 8),
                ],
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
                    "R${room['MonthlyRent']?.toStringAsFixed(2) ?? 'N/A'}/month"),
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

            // In _buildRoomCard method, replace the amenities section with this:

// Amenities
            if (room['Amenities'] != null &&
                (room['Amenities'] as List).isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    "Amenities:",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children:
                        (room['Amenities'] as List).take(4).map((amenity) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A237E).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          amenity,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF1A237E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if ((room['Amenities'] as List).length > 4) ...[
                    const SizedBox(height: 4),
                    Text(
                      "+ ${(room['Amenities'] as List).length - 4} more",
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),

            const SizedBox(height: 12),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editRoom(roomId, room),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text("Edit"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _deleteRoom(roomId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                    ),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text("Delete"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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

  Future<void> _saveRoom() async {
    if (_roomNumberController.text.isEmpty ||
        _monthlyRentController.text.isEmpty ||
        _capacityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String roomId;
      List<String> allImages = [..._roomImages]; // Start with existing images

      if (_editingRoomId == null) {
        // Add new room - create document first
        final docRef = await FirebaseFirestore.instance
            .collection("Accommodations")
            .doc(widget.accommodationId)
            .collection("Rooms")
            .add({
          "RoomNumber": _roomNumberController.text.trim(),
          "RoomType": _roomType,
          "MonthlyRent":
              double.tryParse(_monthlyRentController.text.trim()) ?? 0.0,
          "Capacity": int.tryParse(_capacityController.text.trim()) ?? 1,
          "AvailabilityStatus": _availabilityStatus,
          "Description": _descriptionController.text.trim(),
          "Amenities": _roomAmenities,
          "AccommodationID": widget.accommodationId,
          "Images": allImages, // Add existing images
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        });

        roomId = docRef.id;

        // Upload new images and update the document
        if (_selectedImages.isNotEmpty) {
          final uploadedUrls = await _uploadImages(roomId);
          allImages.addAll(uploadedUrls);

          await docRef.update({
            "Images": allImages,
            "updatedAt": FieldValue.serverTimestamp(),
          });
        }
      } else {
        // Update existing room
        roomId = _editingRoomId!;

        // Upload new images first
        if (_selectedImages.isNotEmpty) {
          final uploadedUrls = await _uploadImages(roomId);
          allImages.addAll(uploadedUrls);
        }

        await FirebaseFirestore.instance
            .collection("Accommodations")
            .doc(widget.accommodationId)
            .collection("Rooms")
            .doc(_editingRoomId)
            .update({
          "RoomNumber": _roomNumberController.text.trim(),
          "RoomType": _roomType,
          "MonthlyRent":
              double.tryParse(_monthlyRentController.text.trim()) ?? 0.0,
          "Capacity": int.tryParse(_capacityController.text.trim()) ?? 1,
          "AvailabilityStatus": _availabilityStatus,
          "Description": _descriptionController.text.trim(),
          "Amenities": _roomAmenities,
          "Images": allImages,
          "updatedAt": FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editingRoomId == null
              ? "Room added successfully"
              : "Room updated successfully"),
          backgroundColor: Colors.green,
        ),
      );

      _clearForm();
      setState(() {
        _showAddForm = false;
        _editingRoomId = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving room: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _editRoom(String roomId, Map<String, dynamic> room) {
    setState(() {
      _editingRoomId = roomId;
      _showAddForm = true;

      _roomNumberController.text = room['RoomNumber'] ?? '';
      _roomType = room['RoomType'] ?? 'Single';
      _monthlyRentController.text = room['MonthlyRent']?.toString() ?? '';
      _capacityController.text = room['Capacity']?.toString() ?? '';
      _availabilityStatus = room['AvailabilityStatus'] ?? 'Available';
      _descriptionController.text = room['Description'] ?? '';
      _roomAmenities = List<String>.from(room['Amenities'] ?? []);
      _roomImages = List<String>.from(room['Images'] ?? []);
      _selectedImages.clear(); // Clear any previously selected new images
    });
  }

  Future<void> _deleteRoom(String roomId) async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Room"),
        content: const Text(
            "Are you sure you want to delete this room? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        await FirebaseFirestore.instance
            .collection("Accommodations")
            .doc(widget.accommodationId)
            .collection("Rooms")
            .doc(roomId)
            .delete();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Room deleted successfully"),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error deleting room: $e"),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _cancelEdit() {
    _clearForm();
    setState(() {
      _showAddForm = false;
      _editingRoomId = null;
    });
  }

  void _clearForm() {
    _roomNumberController.clear();
    _monthlyRentController.clear();
    _capacityController.clear();
    _descriptionController.clear();
    _roomAmenities.clear();
    _roomImages.clear();
    _selectedImages.clear();
    _availabilityStatus = "Available";
    _roomType = "Single";
  }
}
