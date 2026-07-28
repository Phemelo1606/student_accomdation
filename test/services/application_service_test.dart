import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_accomdation/services/applicationService.dart';

void main() {
  group('ApplicationService.acceptApplication', () {
    late FakeFirebaseFirestore firestore;
    late ApplicationService service;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      service = ApplicationService(firestore: firestore);

      await firestore.collection('Applications').doc('app1').set({
        'StudentID': 'student1',
        'Status': 'Pending',
      });
      await firestore.collection('Rooms').doc('room1').set({
        'AvailabilityStatus': 'Available',
      });
    });

    test('marks the application as Accepted', () async {
      await service.acceptApplication('app1', 'room1');

      final appDoc =
          await firestore.collection('Applications').doc('app1').get();
      expect(appDoc.data()!['Status'], 'Accepted');
      expect(appDoc.data()!['AcceptedAt'], isNotNull);
    });

    test('links the room to the student in StudentRooms', () async {
      await service.acceptApplication('app1', 'room1');

      final studentRoomDoc =
          await firestore.collection('StudentRooms').doc('student1').get();
      expect(studentRoomDoc.exists, isTrue);
      expect(studentRoomDoc.data()!['RoomID'], 'room1');
      expect(studentRoomDoc.data()!['ApplicationID'], 'app1');
      expect(studentRoomDoc.data()!['IsActive'], isTrue);
    });

    test('marks the room as Occupied', () async {
      await service.acceptApplication('app1', 'room1');

      final roomDoc = await firestore.collection('Rooms').doc('room1').get();
      expect(roomDoc.data()!['AvailabilityStatus'], 'Occupied');
    });

    test('throws when the application does not exist', () async {
      expect(
        () => service.acceptApplication('missing-app', 'room1'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
