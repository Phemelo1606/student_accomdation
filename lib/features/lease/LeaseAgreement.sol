// LeaseAgreement.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract LeaseAgreement {
    struct Lease {
        uint256 leaseId;
        address landlord;
        address student;
        string ipfsHash;
        string leaseTerms;
        uint256 createdAt;
        uint256 signedAt;
        bool isSigned;
        bool isStored;
    }

    mapping(uint256 => Lease) public leases;
    mapping(string => uint256) public ipfsToLeaseId;
    uint256 private nextLeaseId = 1;

    event LeaseCreated(
        uint256 indexed leaseId,
        address indexed landlord,
        address indexed student,
        string ipfsHash,
        uint256 createdAt
    );

    event LeaseSigned(
        uint256 indexed leaseId,
        address indexed student,
        uint256 signedAt
    );

    event LeaseStored(
        uint256 indexed leaseId,
        string ipfsHash,
        uint256 storedAt
    );

    function createLease(
        address student,
        string memory ipfsHash,
        string memory leaseTerms
    ) external returns (uint256) {
        require(student != address(0), "Invalid student address");
        require(bytes(ipfsHash).length > 0, "IPFS hash required");

        uint256 leaseId = nextLeaseId++;

        leases[leaseId] = Lease({
            leaseId: leaseId,
            landlord: msg.sender,
            student: student,
            ipfsHash: ipfsHash,
            leaseTerms: leaseTerms,
            createdAt: block.timestamp,
            signedAt: 0,
            isSigned: false,
            isStored: true
        });

        ipfsToLeaseId[ipfsHash] = leaseId;

        emit LeaseCreated(leaseId, msg.sender, student, ipfsHash, block.timestamp);
        emit LeaseStored(leaseId, ipfsHash, block.timestamp);

        return leaseId;
    }

    function signLease(uint256 leaseId) external {
        Lease storage lease = leases[leaseId];
        require(lease.leaseId != 0, "Lease does not exist");
        require(msg.sender == lease.student, "Only student can sign");
        require(!lease.isSigned, "Lease already signed");

        lease.isSigned = true;
        lease.signedAt = block.timestamp;

        emit LeaseSigned(leaseId, msg.sender, block.timestamp);
    }

    function getLease(uint256 leaseId) external view returns (Lease memory) {
        return leases[leaseId];
    }

    function verifyLeaseSignature(uint256 leaseId) external view returns (bool) {
        return leases[leaseId].isSigned;
    }

    function getLeaseByIPFS(string memory ipfsHash) external view returns (Lease memory) {
        uint256 leaseId = ipfsToLeaseId[ipfsHash];
        return leases[leaseId];
    }
}