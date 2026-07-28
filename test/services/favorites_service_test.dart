import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_accomdation/services/favorites_service.dart';

void main() {
  group('FavoritesService', () {
    late FakeFirebaseFirestore firestore;
    late MockFirebaseAuth auth;
    late FavoritesService service;

    const accommodationId = 'acc1';
    final accommodationData = {'Name': 'Sunrise Residence'};
    final roomData = {'RoomNumber': 'A1', 'MonthlyRent': 1500};
    const roomId = 'room1';

    setUp(() {
      firestore = FakeFirebaseFirestore();
      auth = MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'student1'),
      );
      service = FavoritesService(firestore: firestore, auth: auth);
    });

    test('saveAccommodation is reflected by isAccommodationSaved', () async {
      expect(await service.isAccommodationSaved(accommodationId), isFalse);

      await service.saveAccommodation(
          accommodationId, accommodationData, roomData, roomId);

      expect(await service.isAccommodationSaved(accommodationId), isTrue);
    });

    test('saveAccommodation stores the expected fields, scoped to the current user',
        () async {
      await service.saveAccommodation(
          accommodationId, accommodationData, roomData, roomId);

      final doc = await firestore
          .collection('studentFavorites')
          .doc('student1_$accommodationId')
          .get();

      expect(doc.data()!['accommodationId'], accommodationId);
      expect(doc.data()!['roomId'], roomId);
      expect(doc.data()!['studentId'], 'student1');
    });

    test('removeAccommodation deletes the saved favorite', () async {
      await service.saveAccommodation(
          accommodationId, accommodationData, roomData, roomId);
      expect(await service.isAccommodationSaved(accommodationId), isTrue);

      await service.removeAccommodation(accommodationId);

      expect(await service.isAccommodationSaved(accommodationId), isFalse);
    });

    test('saveAccommodation throws when no user is signed in', () async {
      final signedOutAuth = MockFirebaseAuth(signedIn: false);
      final signedOutService =
          FavoritesService(firestore: firestore, auth: signedOutAuth);

      expect(
        () => signedOutService.saveAccommodation(
            accommodationId, accommodationData, roomData, roomId),
        throwsA(isA<Exception>()),
      );
    });

    test('getSavedAccommodations streams only the current user\'s favorites',
        () async {
      await service.saveAccommodation(
          accommodationId, accommodationData, roomData, roomId);
      await service.saveAccommodation(
          'acc2', {'Name': 'Other Place'}, roomData, 'room2');

      final favorites = await service.getSavedAccommodations().first;

      expect(favorites.length, 2);
      expect(
        favorites.map((f) => f['accommodationId']).toSet(),
        {'acc1', 'acc2'},
      );
    });
  });
}
