import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:student_accomdation/services/blockchain_service.dart';

void main() {
  group('BlockchainService', () {
    late FakeFirebaseFirestore firestore;
    late BlockchainService service;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      service = BlockchainService(firestore: firestore);
    });

    test('createLease persists the lease and returns a transaction hash',
        () async {
      final txHash = await service.createLease(
        studentAddress: '0xStudent',
        ipfsHash: 'QmTestHash',
        leaseTerms: '{"rent":1500}',
        privateKey: 'test-key',
      );

      expect(txHash, isNotEmpty);

      final query = await firestore
          .collection('leases')
          .where('ipfsHash', isEqualTo: 'QmTestHash')
          .get();

      expect(query.docs, hasLength(1));
      expect(query.docs.first.data()['transactionHash'], txHash);
      expect(query.docs.first.data()['isSigned'], isFalse);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('getLeaseByIPFS finds a lease created with a matching ipfsHash',
        () async {
      await service.createLease(
        studentAddress: '0xStudent',
        ipfsHash: 'QmFindMe',
        leaseTerms: 'terms',
        privateKey: 'test-key',
      );

      final lease = await service.getLeaseByIPFS('QmFindMe');

      expect(lease['ipfsHash'], 'QmFindMe');
      expect(lease['isSigned'], isFalse);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('getLease returns mock/fallback data for an unknown leaseId',
        () async {
      final lease = await service.getLease('does-not-exist');

      expect(lease['isStored'], isTrue);
      expect(lease['ipfsHash'], contains('QmMockIPFSHash'));
    });

    // Regression test: getLeaseIdFromIPFS() used to try to parse Firestore's
    // (non-numeric) auto-generated document ID as an int and silently fall
    // back to ipfsHash.hashCode.abs(), so signLease() updated a document that
    // didn't match the one createLease() actually made. leaseId is now
    // threaded through as a String end-to-end so this round trip lands on
    // the real document.
    test(
        'full round trip: created lease can be looked up by IPFS hash and signed',
        () async {
      const ipfsHash = 'QmRoundTrip';
      await service.createLease(
        studentAddress: '0xStudent',
        ipfsHash: ipfsHash,
        leaseTerms: 'terms',
        privateKey: 'landlord-key',
      );

      final derivedLeaseId = await service.getLeaseIdFromIPFS(ipfsHash);
      await service.signLease(
        leaseId: derivedLeaseId,
        privateKey: 'student-key',
      );

      final leaseAfterSign = await service.getLeaseByIPFS(ipfsHash);

      expect(leaseAfterSign['isSigned'], isTrue);
      expect(await service.verifyLeaseSignature(derivedLeaseId), isTrue);
    }, timeout: const Timeout(Duration(seconds: 10)));
  });
}
