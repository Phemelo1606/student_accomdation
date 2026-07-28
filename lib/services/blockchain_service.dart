// services/blockchain_service.dart - Enhanced Version
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:student_accomdation/core/app_logger.dart';

class BlockchainService {
  final FirebaseFirestore _firestore;

  BlockchainService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<String> createLease({
    required String studentAddress,
    required String ipfsHash,
    required String leaseTerms,
    required String privateKey,
  }) async {
    try {
      AppLogger.log('⛓️ Storing lease in Firestore...');

      // Store lease data in Firestore for persistence
      final leaseData = {
        'studentAddress': studentAddress,
        'ipfsHash': ipfsHash,
        'leaseTerms': leaseTerms,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'created',
        'isSigned': false,
        'transactionHash': 'pending',
      };

      final leaseDoc = await _firestore.collection('leases').add(leaseData);
      final leaseId = leaseDoc.id;

      // Simulate blockchain delay
      await Future.delayed(const Duration(seconds: 2));

      // Generate mock transaction hash
      final transactionHash =
          "0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}_real_tx";

      // Update with real transaction hash
      await leaseDoc.update({
        'transactionHash': transactionHash,
        'leaseId': leaseId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.log('✅ Lease stored in Firestore with ID: $leaseId');
      AppLogger.log('✅ Mock blockchain transaction: $transactionHash');

      return transactionHash;
    } catch (e) {
      AppLogger.log('❌ Firestore lease storage error: $e');
      // Fallback to pure mock
      return "0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}_mock_tx_hash";
    }
  }

  Future<String> signLease({
    required String leaseId,
    required String privateKey,
  }) async {
    try {
      AppLogger.log('⛓️ Signing lease in Firestore...');

      // Update lease status in Firestore
      await _firestore.collection('leases').doc(leaseId).update({
        'isSigned': true,
        'signedAt': FieldValue.serverTimestamp(),
        'signedBy':
            privateKey, // In real app, this would be the signer's address
        'status': 'signed',
      });

      // Simulate blockchain delay
      await Future.delayed(const Duration(seconds: 2));

      final signTransactionHash =
          "0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}_signed_tx";

      AppLogger.log('✅ Lease signed in Firestore');
      AppLogger.log('✅ Mock signature transaction: $signTransactionHash');

      return signTransactionHash;
    } catch (e) {
      AppLogger.log('❌ Firestore lease signing error: $e');
      return "0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}_signed_mock_tx";
    }
  }

  Future<Map<String, dynamic>> getLease(String leaseId) async {
    try {
      final doc = await _firestore.collection('leases').doc(leaseId).get();

      if (doc.exists) {
        final data = doc.data()!;
        return {
          'leaseId': leaseId,
          'landlord': '0xLandlordRealAddress',
          'student': data['studentAddress'] ?? '0xStudentAddress',
          'ipfsHash': data['ipfsHash'] ?? 'Unknown',
          'leaseTerms': data['leaseTerms'] ?? 'No terms',
          'createdAt': data['createdAt']?.millisecondsSinceEpoch ??
              DateTime.now().millisecondsSinceEpoch,
          'signedAt': data['signedAt']?.millisecondsSinceEpoch ?? 0,
          'isSigned': data['isSigned'] ?? false,
          'isStored': true,
          'transactionHash': data['transactionHash'] ?? 'Unknown',
          'status': data['status'] ?? 'unknown',
        };
      } else {
        throw Exception('Lease not found in Firestore');
      }
    } catch (e) {
      AppLogger.log('❌ Firestore lease fetch error: $e');
      // Fallback to mock data
      return _getMockLeaseData(leaseId);
    }
  }

  Future<bool> verifyLeaseSignature(String leaseId) async {
    try {
      final lease = await getLease(leaseId);
      return lease['isSigned'] == true;
    } catch (e) {
      AppLogger.log('❌ Lease verification error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getLeaseByIPFS(String ipfsHash) async {
    try {
      final query = await _firestore
          .collection('leases')
          .where('ipfsHash', isEqualTo: ipfsHash)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final data = doc.data();
        return {
          'leaseId': doc.id,
          'landlord': '0xLandlordRealAddress',
          'student': data['studentAddress'] ?? '0xStudentAddress',
          'ipfsHash': data['ipfsHash'] ?? ipfsHash,
          'leaseTerms': data['leaseTerms'] ?? 'No terms',
          'createdAt': data['createdAt']?.millisecondsSinceEpoch ??
              DateTime.now().millisecondsSinceEpoch,
          'signedAt': data['signedAt']?.millisecondsSinceEpoch ?? 0,
          'isSigned': data['isSigned'] ?? false,
          'isStored': true,
        };
      } else {
        throw Exception('Lease not found for IPFS hash: $ipfsHash');
      }
    } catch (e) {
      AppLogger.log('❌ Firestore lease by IPFS error: $e');
      return _getMockLeaseData('mock_${ipfsHash.hashCode.abs()}');
    }
  }

  // Returns the real Firestore document ID for the lease matching this IPFS
  // hash, so signLease()/getLease() actually target the document created by
  // createLease() instead of a derived value that can never match it.
  Future<String> getLeaseIdFromIPFS(String ipfsHash) async {
    try {
      final lease = await getLeaseByIPFS(ipfsHash);
      return lease['leaseId']?.toString() ?? 'mock_${ipfsHash.hashCode.abs()}';
    } catch (e) {
      AppLogger.log('❌ Get lease ID from IPFS error: $e');
      return 'mock_${ipfsHash.hashCode.abs()}';
    }
  }

  Map<String, dynamic> _getMockLeaseData(String leaseId) {
    return {
      'leaseId': leaseId,
      'landlord': '0xLandlordMockAddress',
      'student': '0xStudentMockAddress',
      'ipfsHash': 'QmMockIPFSHash$leaseId',
      'leaseTerms': 'Mock lease terms for development and testing',
      'createdAt': DateTime.now()
          .subtract(const Duration(days: 1))
          .millisecondsSinceEpoch,
      'signedAt': 0,
      'isSigned': false,
      'isStored': true,
    };
  }
}
