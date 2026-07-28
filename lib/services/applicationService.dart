// Enhanced Application System
import 'package:cloud_firestore/cloud_firestore.dart';

class ApplicationService {
  final FirebaseFirestore _firestore;

  ApplicationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Landlord accepts application
  Future<void> acceptApplication(String applicationId, String roomId) async {
    try {
      // Get application data
      final applicationDoc = await _firestore
          .collection('Applications')
          .doc(applicationId)
          .get();

      final applicationData = applicationDoc.data()!;
      final studentId = applicationData['StudentID'];

      // Update application status
      await _firestore.collection('Applications').doc(applicationId).update({
        'Status': 'Accepted',
        'AcceptedAt': FieldValue.serverTimestamp(),
      });

      // Link room to student
      await _linkRoomToStudent(roomId, studentId, applicationId);

      // Mark room as occupied
      await _updateRoomStatus(roomId, 'Occupied');

    } catch (e) {
      throw Exception('Error accepting application: $e');
    }
  }

  // Link room to student
  Future<void> _linkRoomToStudent(
    String roomId,
    String studentId,
    String applicationId
  ) async {
    await _firestore.collection('StudentRooms').doc(studentId).set({
      'RoomID': roomId,
      'StudentID': studentId,
      'ApplicationID': applicationId,
      'LeaseStartDate': FieldValue.serverTimestamp(),
      'IsActive': true,
      'CreatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Update room status
  Future<void> _updateRoomStatus(String roomId, String status) async {
    await _firestore.collection('Rooms').doc(roomId).update({
      'AvailabilityStatus': status,
      'UpdatedAt': FieldValue.serverTimestamp(),
    });
  }
}