// features/chat/room_selection_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:student_accomdation/core/app_logger.dart';

class RoomSelectionDialog extends StatefulWidget {
  final String landlordId;
  final String landlordName;
  final String studentName;
  final List<Map<String, dynamic>> availableRooms;

  const RoomSelectionDialog({
    super.key,
    required this.landlordId,
    required this.landlordName,
    required this.studentName,
    required this.availableRooms,
  });

  @override
  State<RoomSelectionDialog> createState() => _RoomSelectionDialogState();
}

class _RoomSelectionDialogState extends State<RoomSelectionDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _availableRooms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Use provided rooms or fetch them
    if (widget.availableRooms.isNotEmpty) {
      _availableRooms = widget.availableRooms;
      _isLoading = false;
    } else {
      _loadRooms();
    }
  }

  Future<void> _debugFirestoreStructure() async {
    try {
      AppLogger.log('🔍 DEBUG: Checking specific accommodation structure...');

      // Check landlord's accommodations to get the accommodation ID
      final landlordAccommodations = await _firestore
          .collection('landlords')
          .doc(widget.landlordId)
          .collection('accommodations')
          .get();

      AppLogger.log(
          '🏢 Landlord accommodations: ${landlordAccommodations.docs.length}');

      for (final acc in landlordAccommodations.docs) {
        final accommodationId = acc.id;
        AppLogger.log('📋 Checking accommodation: $accommodationId');

        // Check if rooms exist in Accommodations collection using this ID
        final rooms = await _firestore
            .collection('Accommodations')
            .doc(accommodationId)
            .collection('Rooms')
            .get();

        AppLogger.log('   🏠 Rooms found: ${rooms.docs.length}');

        for (final room in rooms.docs) {
          final roomData = room.data();
          AppLogger.log('      📋 Room ID: ${room.id}');
          AppLogger.log('      📊 RoomNumber: ${roomData['RoomNumber']}');
          AppLogger.log('      📊 Status: ${roomData['AvailabilityStatus']}');
          AppLogger.log(
              '      📊 AccommodationID in room: ${roomData['AccommodationID']}');
        }

        // Also check if the main accommodation document exists
        final mainAccDoc = await _firestore
            .collection('Accommodations')
            .doc(accommodationId)
            .get();

        AppLogger.log('   🔗 Main accommodation document exists: ${mainAccDoc.exists}');
        if (mainAccDoc.exists) {
          AppLogger.log('   📊 Main accommodation data: ${mainAccDoc.data()}');
        }
      }
    } catch (e) {
      AppLogger.log('❌ DEBUG Error: $e');
    }
  }

  Future<void> _loadRooms() async {
    try {
      AppLogger.log('🔍 Loading available rooms for landlord: ${widget.landlordId}');

      // Get accommodations from landlord's subcollection
      final accommodationsSnapshot = await _firestore
          .collection('landlords')
          .doc(widget.landlordId)
          .collection('accommodations')
          .get();

      AppLogger.log(
          '🏢 Found ${accommodationsSnapshot.docs.length} accommodations in landlord subcollection');

      List<Map<String, dynamic>> availableRooms = [];

      for (final accDoc in accommodationsSnapshot.docs) {
        final accommodationData = accDoc.data();
        final accommodationId = accDoc.id;

        AppLogger.log('📋 Processing accommodation: $accommodationId');

        // DIRECTLY query rooms using the accommodation ID from landlord's subcollection
        final roomsSnapshot = await _firestore
            .collection('Accommodations')
            .doc(accommodationId)
            .collection('Rooms')
            .where('AvailabilityStatus', isEqualTo: 'Available')
            .get();

        AppLogger.log('   🔍 Found ${roomsSnapshot.docs.length} available rooms');

        for (final roomDoc in roomsSnapshot.docs) {
          final roomData = roomDoc.data();
          availableRooms.add({
            ...roomData,
            'roomId': roomDoc.id,
            'accommodationId': accommodationId,
            'accommodationName':
                accommodationData['Name'] ?? 'Unknown Accommodation',
            'accommodationLocation': accommodationData['Location'] ?? '',
          });
        }
      }

      setState(() {
        _availableRooms = availableRooms;
        _isLoading = false;
      });

      AppLogger.log('✅ Loaded ${_availableRooms.length} available rooms');
    } catch (e) {
      AppLogger.log('❌ Error loading rooms: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select a Room',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Landlord: ${widget.landlordName}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
      content: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading available rooms...'),
                ],
              ),
            )
          : _availableRooms.isEmpty
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.meeting_room, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No available rooms found',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'All rooms are currently occupied or under maintenance',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                )
              : SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_availableRooms.length} room${_availableRooms.length == 1 ? '' : 's'} available',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _availableRooms.length,
                          itemBuilder: (context, index) {
                            final room = _availableRooms[index];
                            final roomNumber = room['RoomNumber'] ?? 'N/A';
                            final roomType = room['RoomType'] ?? 'N/A';
                            final monthlyRent = room['MonthlyRent'] ?? 0;
                            final accommodationName =
                                room['accommodationName'] ?? 'Unknown';
                            final capacity = room['Capacity'] ?? 1;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              elevation: 1,
                              child: ListTile(
                                leading: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.meeting_room,
                                    color: Colors.blue[700],
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  'Room $roomNumber',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '$roomType • $capacity person${capacity == 1 ? '' : 's'}'),
                                    Text(accommodationName),
                                    Text(
                                      'R${monthlyRent.toStringAsFixed(0)}/month',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right,
                                    color: Colors.grey),
                                onTap: () {
                                  AppLogger.log('✅ Room selected: $roomNumber');
                                  Navigator.pop(context, room);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
      actions: [
        TextButton(
          onPressed: () {
            AppLogger.log('❌ Room selection cancelled');
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
