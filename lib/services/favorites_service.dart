// services/favorites_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:student_accomdation/core/app_logger.dart';

class FavoritesService {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FavoritesService({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // Save accommodation to favorites
  Future<void> saveAccommodation(
    String accommodationId,
    Map<String, dynamic> accommodationData,
    Map<String, dynamic> roomData,
    String roomId,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      AppLogger.log('💾 SAVE: Starting save for accommodation: $accommodationId');
      AppLogger.log('💾 SAVE: User ID: ${user.uid}');
      AppLogger.log('💾 SAVE: Room ID: $roomId');

      final favoriteData = {
        'accommodationId': accommodationId,
        'roomId': roomId,
        'accommodationData': accommodationData,
        'roomData': roomData,
        'savedAt': FieldValue.serverTimestamp(),
        'studentId': user.uid,
      };

      final docId = '${user.uid}_$accommodationId';
      AppLogger.log('💾 SAVE: Document ID: $docId');

      await _firestore
          .collection('studentFavorites')
          .doc(docId)
          .set(favoriteData, SetOptions(merge: true));

      AppLogger.log('✅ SAVE: Successfully saved accommodation: $accommodationId');
    } catch (e) {
      AppLogger.log('❌ SAVE: Error saving accommodation: $e');
      rethrow;
    }
  }

  // Remove accommodation from favorites
  Future<void> removeAccommodation(String accommodationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      AppLogger.log('🗑️ REMOVE: Removing accommodation: $accommodationId');
      AppLogger.log('🗑️ REMOVE: User ID: ${user.uid}');

      final docId = '${user.uid}_$accommodationId';
      await _firestore.collection('studentFavorites').doc(docId).delete();

      AppLogger.log('✅ REMOVE: Successfully removed accommodation: $accommodationId');
    } catch (e) {
      AppLogger.log('❌ REMOVE: Error removing accommodation: $e');
      rethrow;
    }
  }

  // Check if accommodation is saved
  Future<bool> isAccommodationSaved(String accommodationId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        AppLogger.log('🔍 CHECK: No user logged in');
        return false;
      }

      final docId = '${user.uid}_$accommodationId';
      final doc =
          await _firestore.collection('studentFavorites').doc(docId).get();

      final exists = doc.exists;
      AppLogger.log('🔍 CHECK: Accommodation $accommodationId -> $exists');
      return exists;
    } catch (e) {
      AppLogger.log('❌ CHECK: Error checking if saved: $e');
      return false;
    }
  }

  // Get all saved accommodations for current user
  Stream<List<Map<String, dynamic>>> getSavedAccommodations() {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        AppLogger.log('🔄 STREAM: No user logged in, returning empty stream');
        return const Stream.empty();
      }

      AppLogger.log('🔄 STREAM: Starting stream for user: ${user.uid}');

      return _firestore
          .collection('studentFavorites')
          .where('studentId', isEqualTo: user.uid)
          .orderBy('savedAt', descending: true)
          .snapshots()
          .handleError((error) {
        AppLogger.log('❌ STREAM: Error in stream: $error');
        AppLogger.log('❌ STREAM: Error type: ${error.runtimeType}');
        AppLogger.log('❌ STREAM: Stack trace: ${error.stackTrace}');
      }).map((snapshot) {
        final favorites = snapshot.docs.map((doc) {
          final data = doc.data();
          AppLogger.log('📄 STREAM: Document ${doc.id}');
          AppLogger.log('📄 STREAM: Data: $data');
          return data;
        }).toList();
        AppLogger.log('📊 STREAM: Updated with ${favorites.length} favorites');
        return favorites;
      });
    } catch (e) {
      AppLogger.log('❌ STREAM: Error creating stream: $e');
      return Stream.error(e);
    }
  }
}
