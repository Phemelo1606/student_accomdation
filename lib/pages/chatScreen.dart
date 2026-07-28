import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:student_accomdation/features/chat/room_selection_dialog.dart';
import 'dart:convert';
import 'package:student_accomdation/services/blockchain_service.dart';
import 'package:student_accomdation/services/ipfs_service.dart';
import 'package:student_accomdation/services/pdf_service.dart';
import 'package:student_accomdation/widgets/lease_editor_dialog.dart';
import 'package:student_accomdation/core/app_logger.dart';

class ChatScreen extends StatefulWidget {
  final String landlordId;
  final String landlordName;
  final String studentId;
  final String studentName;

  const ChatScreen({
    super.key,
    required this.landlordId,
    required this.landlordName,
    required this.studentId,
    required this.studentName,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _scrollController = ScrollController();
  final BlockchainService _blockchainService = BlockchainService();
  final PDFIPFSService _ipfsService = PDFIPFSService();
  final PDFService _pdfService = PDFService();

  String _chatId = '';
  bool _isSending = false;
  bool _showLeaseOptions = false;
  bool _isLandlord = false;

  // REMOVED: Default room constants
  // String _selectedRoomId = '';
  // String _selectedAccommodationId = '';
  Map<String, dynamic>? _selectedRoom;

  @override
  void initState() {
    super.initState();
    AppLogger.log('💬 ChatScreen initialized with:');
    AppLogger.log('   Landlord: ${widget.landlordName} (${widget.landlordId})');
    AppLogger.log('   Student: ${widget.studentName} (${widget.studentId})');
    _checkUserRole();
    _initializeChat();
  }

  void _checkUserRole() {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      _isLandlord = currentUser.uid == widget.landlordId;
      AppLogger.log('👤 User is ${_isLandlord ? 'Landlord' : 'Student'}');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    try {
      AppLogger.log('🔄 Initializing chat...');
      _chatId = await createOrGetChat(widget.studentId, widget.landlordId);
      AppLogger.log('✅ Chat initialized successfully');
      AppLogger.log('   Chat ID: $_chatId');
      setState(() {});

      // Scroll to bottom after a short delay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      AppLogger.log('❌ Error initializing chat: $e');
    }
  }

  Future<String> createOrGetChat(String studentId, String landlordId) async {
    final chatId = '${studentId}_$landlordId';
    AppLogger.log('   Generating chat ID: $chatId');

    final chatDoc = _firestore.collection('chats').doc(chatId);

    AppLogger.log('   Checking if chat exists in Firestore...');
    final docSnapshot = await chatDoc.get();

    if (!docSnapshot.exists) {
      AppLogger.log('   Creating new chat document...');
      await chatDoc.set({
        'participants': [studentId, landlordId],
        'createdAt': FieldValue.serverTimestamp(),
        'studentName': widget.studentName,
        'landlordName': widget.landlordName,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });
      AppLogger.log('   ✅ New chat document created');
    } else {
      AppLogger.log('   ✅ Existing chat document found');
    }

    return chatId;
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending || _chatId.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      AppLogger.log('❌ No user logged in');
      setState(() {
        _isSending = false;
      });
      return;
    }

    AppLogger.log('📤 Sending message: "$text"');
    AppLogger.log('   Chat ID: $_chatId');
    AppLogger.log('   Sender ID: ${currentUser.uid}');

    try {
      final messagesRef =
          _firestore.collection('chats').doc(_chatId).collection('messages');

      // Add the message
      final messageData = {
        'senderId': currentUser.uid,
        'text': text,
        'type': 'text',
        'timestamp': FieldValue.serverTimestamp(),
      };

      AppLogger.log('   Message data: $messageData');

      await messagesRef.add(messageData);
      AppLogger.log('   ✅ Message stored successfully');

      // Update last message timestamp in chat document
      await _firestore.collection('chats').doc(_chatId).update({
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });
      AppLogger.log('   ✅ Chat document updated with last message timestamp');

      // Clear input field
      _messageController.clear();

      // Scroll to bottom to show new message
      _scrollToBottom();
    } catch (e) {
      AppLogger.log('❌ Error sending message: $e');
      AppLogger.log('   Error type: ${e.runtimeType}');

      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // LEASE AGREEMENT FUNCTIONS
  void _toggleLeaseOptions() {
    setState(() {
      _showLeaseOptions = !_showLeaseOptions;
    });
  }

  Future<void> _createAndSendLease() async {
    try {
      // Show room selection dialog first
      final selectedRoom = await _selectRoom();
      if (selectedRoom == null) {
        AppLogger.log('Room selection cancelled by user');
        return;
      }

      // Create initial lease agreement data with selected room
      final initialLeaseData = {
        'landlordName': widget.landlordName,
        'studentName': widget.studentName,
        'LandlordID': widget.landlordId,
        'studentId': widget.studentId,
        'roomDetails': selectedRoom,
        'monthlyRent': selectedRoom['MonthlyRent']?.toString() ?? 'R0',
        'leaseDuration': '12 months',
        'startDate':
            DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'endDate':
            DateTime.now().add(const Duration(days: 395)).toIso8601String(),
        'termsAndConditions': _getDefaultTerms(),
        'createdAt': DateTime.now().toIso8601String(),
        'status': 'draft',
      };

      if (!mounted) return;

      // Show lease editor dialog
      final editedLease = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => LeaseEditorDialog(
          initialLeaseData: initialLeaseData,
          landlordName: widget.landlordName,
          studentName: widget.studentName,
        ),
      );

      if (editedLease == null) {
        AppLogger.log('Lease creation cancelled by user');
        return;
      }

      // Store the selected room for later use
      _selectedRoom = selectedRoom;

      // Proceed with sending the edited lease
      await _sendLeaseToBlockchain(editedLease);
    } catch (e) {
      AppLogger.log('❌ Lease creation error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to create lease: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // Room selection method
  Future<Map<String, dynamic>?> _selectRoom() async {
    try {
      AppLogger.log('🏠 Starting room selection...');
      AppLogger.log('   Landlord: ${widget.landlordName} (${widget.landlordId})');

      final availableRooms = await _getAvailableRoomsForLandlord();

      await _debugFirestoreStructure();

      if (!mounted) return null;

      final selectedRoom = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => RoomSelectionDialog(
          availableRooms: availableRooms, // Add this required parameter
          landlordName: widget.landlordName, // Add this required parameter
          studentName: widget.studentName, // Add this required parameter
          landlordId: widget.landlordId, // Keep existing parameter if needed
        ),
      );

      if (selectedRoom != null) {
        // Validate that we have the required room data
        if (selectedRoom['roomId'] == null ||
            selectedRoom['accommodationId'] == null) {
          AppLogger.log('❌ Selected room missing required data');
          if (!mounted) return null;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selected room is missing required information'),
              backgroundColor: Colors.red,
            ),
          );
          return null;
        }

        AppLogger.log('✅ Room selected: ${selectedRoom['RoomNumber']}');
        AppLogger.log('   Room ID: ${selectedRoom['roomId']}');
        AppLogger.log('   Accommodation ID: ${selectedRoom['AccommodationID']}');
        return selectedRoom;
      } else {
        AppLogger.log('❌ No room selected');
        return null;
      }
    } catch (e) {
      AppLogger.log('❌ Error selecting room: $e');
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting room: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _getAvailableRoomsForLandlord() async {
    try {
      AppLogger.log('🔍 Fetching available rooms for landlord: ${widget.landlordId}');

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
        final accommodationId = accDoc.id; // This is s0v7smVa6o16N2bVVc2P

        AppLogger.log('📋 Processing accommodation: $accommodationId');

        // DIRECTLY query the rooms using the known accommodation ID
        // Even if the accommodation document doesn't exist, the rooms subcollection might
        final roomsSnapshot = await _firestore
            .collection('Accommodations')
            .doc(accommodationId) // Use s0v7smVa6o16N2bVVc2P directly
            .collection('Rooms')
            .where('AvailabilityStatus', isEqualTo: 'Available')
            .get();

        AppLogger.log(
            '   🔍 Found ${roomsSnapshot.docs.length} available rooms in Accommodations/$accommodationId/Rooms');

        for (final roomDoc in roomsSnapshot.docs) {
          final roomData = roomDoc.data();
          AppLogger.log(
              '   🏠 Room ${roomDoc.id}: ${roomData['RoomNumber']} - ${roomData['RoomType']}');

          availableRooms.add({
            ...roomData,
            'roomId': roomDoc.id,
            'accommodationId': accommodationId,
            'accommodationName':
                accommodationData['Name'] ?? 'Unknown Accommodation',
            'accommodationLocation': accommodationData['Location'] ?? '',
            'AccommodationName':
                accommodationData['Name'] ?? 'Unknown Accommodation',
          });
        }
      }

      AppLogger.log('✅ Total available rooms found: ${availableRooms.length}');
      return availableRooms;
    } catch (e) {
      AppLogger.log('❌ Error fetching available rooms: $e');
      AppLogger.log('   Error type: ${e.runtimeType}');
      return [];
    }
  }

  Future<void> _sendLeaseToBlockchain(Map<String, dynamic> leaseData) async {
    setState(() {
      _isSending = true;
    });

    try {
      AppLogger.log('📝 Sending edited lease agreement...');
      AppLogger.log('📄 Lease data: ${jsonEncode(leaseData)}');

      // Upload PDF to IPFS
      AppLogger.log('🔄 Uploading PDF to IPFS...');
      final ipfsHash = await _ipfsService.uploadLeasePDFToIPFS(leaseData);

      // Store on blockchain
      AppLogger.log('⛓️ Storing on blockchain...');
      final transactionHash = await _blockchainService.createLease(
        studentAddress: _getStudentBlockchainAddress(),
        ipfsHash: ipfsHash,
        leaseTerms: jsonEncode(leaseData),
        privateKey: _getLandlordPrivateKey(),
      );

      AppLogger.log('✅ Blockchain transaction: $transactionHash');

      // Send lease message in chat with PDF info
      await _sendLeaseMessage(ipfsHash, transactionHash, leaseData, true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ PDF Lease agreement sent successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      setState(() {
        _showLeaseOptions = false;
      });
    } catch (e) {
      AppLogger.log('❌ Lease sending error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to send lease: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // Template lease creation methods - UPDATED TO USE SELECTED ROOM
  Future<void> _createStandardLease() async {
    final selectedRoom = await _selectRoom();
    if (selectedRoom == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No room selected')),
      );
      return;
    }

    final leaseData = {
      'landlordName': widget.landlordName,
      'studentName': widget.studentName,
      'LandlordID': widget.landlordId,
      'studentId': widget.studentId,
      'roomDetails': selectedRoom,
      'monthlyRent':
          'R${selectedRoom['MonthlyRent']?.toStringAsFixed(2) ?? '0'}',
      'leaseDuration': '12 months',
      'startDate':
          DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'endDate':
          DateTime.now().add(const Duration(days: 395)).toIso8601String(),
      'termsAndConditions': _getDefaultTerms(),
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'draft',
      'template': 'standard',
    };

    // Store the selected room for later use
    _selectedRoom = selectedRoom;

    await _sendLeaseToBlockchain(leaseData);
  }

  Future<void> _debugFirestoreStructure() async {
    try {
      AppLogger.log('🔍 DEBUG: Checking Firestore structure...');

      // Check main Accommodations collection for this landlord
      AppLogger.log('👤 Checking main Accommodations collection...');
      final mainAccommodations = await _firestore
          .collection('Accommodations')
          .where('LandlordID', isEqualTo: widget.landlordId)
          .get();

      AppLogger.log(
          '🏢 Main accommodations for landlord: ${mainAccommodations.docs.length}');
      for (final acc in mainAccommodations.docs) {
        final accommodationId = acc.id;
        AppLogger.log('   📋 Accommodation ID: $accommodationId');
        AppLogger.log('   📊 Data: ${acc.data()}');

        // Check rooms in this accommodation
        final rooms = await _firestore
            .collection('Accommodations')
            .doc(accommodationId)
            .collection('Rooms')
            .get();

        AppLogger.log('   🏠 Rooms in accommodation: ${rooms.docs.length}');
        for (final room in rooms.docs) {
          final roomData = room.data();
          final roomStatus = roomData['AvailabilityStatus'] ?? 'NO STATUS';
          AppLogger.log('      📋 Room: ${room.id}');
          AppLogger.log('      📊 Status: $roomStatus');
          AppLogger.log('      📊 RoomNumber: ${roomData['RoomNumber'] ?? 'N/A'}');
          AppLogger.log(
              '      📊 AccommodationID in room: ${roomData['AccommodationID'] ?? 'N/A'}');
        }

        AppLogger.log('   ──────────────────────────');
      }
    } catch (e) {
      AppLogger.log('❌ DEBUG Error: $e');
    }
  }

  Future<void> _createShortTermLease() async {
    final selectedRoom = await _selectRoom();
    if (selectedRoom == null) return;

    final leaseData = {
      'landlordName': widget.landlordName,
      'studentName': widget.studentName,
      'LandlordID': widget.landlordId,
      'studentId': widget.studentId,
      'roomDetails': selectedRoom,
      'monthlyRent':
          'R${(selectedRoom['MonthlyRent'] ?? 0) * 1.1}', // 10% higher for short term
      'leaseDuration': '6 months',
      'startDate':
          DateTime.now().add(const Duration(days: 14)).toIso8601String(),
      'endDate':
          DateTime.now().add(const Duration(days: 184)).toIso8601String(),
      'termsAndConditions': _getShortTermTerms(),
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'draft',
      'template': 'short_term',
    };

    _selectedRoom = selectedRoom;
    await _sendLeaseToBlockchain(leaseData);
  }

  Future<void> _createPremiumLease() async {
    final selectedRoom = await _selectRoom();
    if (selectedRoom == null) return;

    // Create a copy to avoid modifying the original
    final premiumRoom = Map<String, dynamic>.from(selectedRoom);
    premiumRoom['roomType'] = 'Premium ${premiumRoom['RoomType']}';
    premiumRoom['amenities'] = [
      ...(premiumRoom['Amenities'] ?? []),
      'En-suite Bathroom',
      'Premium Furniture',
      'Weekly Cleaning'
    ];

    final leaseData = {
      'landlordName': widget.landlordName,
      'Name': widget.studentName,
      'LandlordID': widget.landlordId,
      'studentId': widget.studentId,
      'roomDetails': premiumRoom,
      'monthlyRent':
          'R${(premiumRoom['MonthlyRent'] ?? 0) * 1.5}', // 50% higher for premium
      'leaseDuration': '12 months',
      'startDate':
          DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'endDate':
          DateTime.now().add(const Duration(days: 395)).toIso8601String(),
      'termsAndConditions': _getPremiumTerms(),
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'draft',
      'template': 'premium',
    };

    _selectedRoom = selectedRoom;
    await _sendLeaseToBlockchain(leaseData);
  }

  // Single lease message sending method
  // Single lease message sending method
  Future<void> _sendLeaseMessage(
    String ipfsHash,
    String transactionHash,
    Map<String, dynamic> leaseData,
    bool isPDFFormat,
  ) async {
    final messagesRef =
        _firestore.collection('chats').doc(_chatId).collection('messages');

    // DEBUG: Check what roomDetails we're receiving
    AppLogger.log('🔍 DEBUG: Room details in leaseData:');
    final roomDetails = leaseData['roomDetails'] ?? {};
    AppLogger.log('   Original roomDetails type: ${roomDetails.runtimeType}');
    AppLogger.log('   Original roomDetails: $roomDetails');

    // Extract individual room properties for debugging
    AppLogger.log('   Room ID: ${roomDetails['roomId']}');
    AppLogger.log('   Accommodation ID: ${roomDetails['accommodationId']}');
    AppLogger.log('   Room Number: ${roomDetails['RoomNumber']}');
    AppLogger.log('   Room Type: ${roomDetails['RoomType']}');
    AppLogger.log('   Monthly Rent: ${roomDetails['MonthlyRent']}');

    // Create enhanced lease data with PROPER room details structure
    final enhancedLeaseData = {
      ...leaseData,
      'roomDetails': {
        'roomId': roomDetails['roomId'] ?? roomDetails['roomId'],
        'accommodationId':
            roomDetails['accommodationId'] ?? roomDetails['accommodationId'],
        'RoomNumber': roomDetails['RoomNumber'] ?? roomDetails['RoomNumber'],
        'RoomType': roomDetails['RoomType'] ?? roomDetails['RoomType'],
        'MonthlyRent': roomDetails['MonthlyRent'] ?? roomDetails['MonthlyRent'],
        'Capacity': roomDetails['Capacity'] ?? roomDetails['Capacity'],
        'accommodationName': roomDetails['accommodationName'] ??
            roomDetails['AccommodationName'],
        'accommodationLocation': roomDetails['accommodationLocation'] ??
            roomDetails['accommodationLocation'],
        'AccommodationName': roomDetails['AccommodationName'] ??
            roomDetails['accommodationName'],
        'Amenities': roomDetails['Amenities'] ?? [],
      },
      'isPDF': isPDFFormat,
      'pdfGeneratedAt': DateTime.now().toIso8601String(),
    };

    AppLogger.log('📝 Storing lease message with enhanced room details:');
    AppLogger.log('   Room ID: ${enhancedLeaseData['roomDetails']['roomId']}');
    AppLogger.log(
        '   Accommodation ID: ${enhancedLeaseData['roomDetails']['accommodationId']}');
    AppLogger.log('   Room Number: ${enhancedLeaseData['roomDetails']['RoomNumber']}');
    AppLogger.log('   Enhanced roomDetails: ${enhancedLeaseData['roomDetails']}');

    await messagesRef.add({
      'senderId': _auth.currentUser!.uid,
      'type': 'lease_agreement',
      'ipfsHash': ipfsHash,
      'transactionHash': transactionHash,
      'leaseData': enhancedLeaseData,
      'leaseStatus': 'sent',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('chats').doc(_chatId).update({
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _resendLeaseWithRoomData(String documentId) async {
    try {
      AppLogger.log('🔄 Re-sending lease with proper room data...');

      // Get the original message
      final messageDoc = await _firestore
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .doc(documentId)
          .get();

      if (!messageDoc.exists) {
        throw Exception('Original lease message not found');
      }

      final messageData = messageDoc.data();
      final originalLeaseData = messageData?['leaseData'] ?? {};

      // Select a room again
      final selectedRoom = await _selectRoom();
      if (selectedRoom == null) {
        throw Exception('Room selection cancelled');
      }

      // Safely construct a Map<String, dynamic> from the original (which may be Map<dynamic, dynamic>)
      final Map<String, dynamic> updatedLeaseData = <String, dynamic>{};
      if (originalLeaseData is Map) {
        originalLeaseData.forEach((k, v) {
          if (k is String) {
            updatedLeaseData[k] = v;
          }
        });
      }

      // Merge/override with the updated fields
      updatedLeaseData['roomDetails'] = Map<String, dynamic>.from(selectedRoom);
      updatedLeaseData['monthlyRent'] =
          selectedRoom['MonthlyRent']?.toString() ?? 'R0';

      // Delete the old lease message
      await _firestore
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .doc(documentId)
          .delete();

      // Send new lease message with proper room data
      await _sendLeaseToBlockchain(updatedLeaseData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Lease re-sent with proper room data'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      AppLogger.log('❌ Error re-sending lease: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to re-send lease: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _signLeaseAgreement(
      String ipfsHash, String transactionHash, String documentId) async {
    try {
      AppLogger.log('⛓️ Signing lease agreement...');
      AppLogger.log('📄 Document ID: $documentId');
      AppLogger.log('🔗 Chat ID: $_chatId');

      // Get the lease data from the message
      final messageDoc = await _firestore
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .doc(documentId)
          .get();

      if (!messageDoc.exists) {
        throw Exception('Lease message not found');
      }

      final messageData = messageDoc.data();
      var leaseData = messageData?['leaseData'] ?? {};

      AppLogger.log('✅ Found lease data for signing');
      AppLogger.log('📊 Full lease data: $leaseData');

      // Check if room data is missing or corrupted
      final roomDetails = leaseData['roomDetails'] ?? {};
      AppLogger.log('🔍 Room details structure: $roomDetails');

      bool hasValidRoomData = roomDetails['roomId'] != null &&
          roomDetails['accommodationId'] != null;

      if (!hasValidRoomData) {
        AppLogger.log('⚠️ Room data missing or corrupted from lease');
        AppLogger.log('   Attempting to recover room data...');

        // Try multiple recovery methods
        Map<String, dynamic>? recoveredRoom;

        // Method 1: Check if we have a previously selected room
        if (_selectedRoom != null) {
          AppLogger.log('✅ Using previously selected room from memory');
          recoveredRoom = _selectedRoom;
        }
        // Method 2: Try to find room by accommodation ID and room number pattern
        else if (leaseData['monthlyRent'] != null) {
          AppLogger.log(
              '🔄 Searching for rooms with similar rent: ${leaseData['monthlyRent']}');
          recoveredRoom = await _findRoomByRent(leaseData['monthlyRent']);
        }
        // Method 3: Get any available room for this landlord
        else {
          AppLogger.log('🔄 Getting first available room for landlord');
          final availableRooms = await _getAvailableRoomsForLandlord();
          if (availableRooms.isNotEmpty) {
            recoveredRoom = availableRooms.first;
            AppLogger.log(
                '✅ Using first available room: ${recoveredRoom['RoomNumber']}');
          }
        }

        if (recoveredRoom != null) {
          leaseData['roomDetails'] = recoveredRoom;
          AppLogger.log('✅ Room data recovered successfully');
          AppLogger.log('   Room ID: ${recoveredRoom['roomId']}');
          AppLogger.log('   Accommodation ID: ${recoveredRoom['accommodationId']}');
        } else {
          throw Exception(
              'Missing room information for assignment. Please ask the landlord to resend the lease with proper room details.');
        }
      }

      // Final validation
      final finalRoomDetails = leaseData['roomDetails'];
      if (finalRoomDetails == null ||
          finalRoomDetails['roomId'] == null ||
          finalRoomDetails['accommodationId'] == null) {
        throw Exception(
            'Cannot sign lease: Room information is still missing. Please contact the landlord to resend the lease.');
      }

      AppLogger.log('✅ Room data validated for signing:');
      AppLogger.log('   Room ID: ${finalRoomDetails['roomId']}');
      AppLogger.log('   Accommodation ID: ${finalRoomDetails['accommodationId']}');
      AppLogger.log('   Room Number: ${finalRoomDetails['RoomNumber']}');

      // Sign on blockchain
      AppLogger.log('⛓️ Signing on blockchain...');
      final leaseId = await _blockchainService.getLeaseIdFromIPFS(ipfsHash);
      final signTransactionHash = await _blockchainService.signLease(
        leaseId: leaseId,
        privateKey: _getStudentPrivateKey(),
      );

      AppLogger.log('✅ Lease signed on blockchain: $signTransactionHash');

      // Update lease status in Firestore
      await _updateLeaseStatus(documentId, 'signed', signTransactionHash);

      // Link room to student
      await _linkRoomToStudentAfterLeaseSign(documentId, leaseData);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Lease signed successfully! Room has been assigned.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );

      // Refresh the UI
      setState(() {});
    } catch (e) {
      AppLogger.log('❌ Error signing lease agreement: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Failed to sign lease: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> _findRoomByRent(dynamic rentValue) async {
    try {
      AppLogger.log('🔍 Searching for room by rent: $rentValue');

      // Get accommodations from landlord's subcollection
      final accommodationsSnapshot = await _firestore
          .collection('landlords')
          .doc(widget.landlordId)
          .collection('accommodations')
          .get();

      for (final accDoc in accommodationsSnapshot.docs) {
        final accommodationId = accDoc.id;
        final accommodationData = accDoc.data();

        // Search for room by monthly rent (convert both to numbers for comparison)
        final roomsSnapshot = await _firestore
            .collection('Accommodations')
            .doc(accommodationId)
            .collection('Rooms')
            .where('AvailabilityStatus', isEqualTo: 'Available')
            .get();

        for (final roomDoc in roomsSnapshot.docs) {
          final roomData = roomDoc.data();
          final roomRent = roomData['MonthlyRent'];

          // Compare rent values (handle different data types)
          if (roomRent != null) {
            final numRoomRent = roomRent is String
                ? double.tryParse(roomRent)
                : roomRent.toDouble();
            final numSearchRent = rentValue is String
                ? double.tryParse(rentValue)
                : rentValue.toDouble();

            if (numRoomRent != null &&
                numSearchRent != null &&
                (numRoomRent - numSearchRent).abs() < 1.0) {
              AppLogger.log('✅ Found matching room by rent: ${roomDoc.id}');

              return {
                ...roomData,
                'roomId': roomDoc.id,
                'accommodationId': accommodationId,
                'accommodationName':
                    accommodationData['Name'] ?? 'Unknown Accommodation',
                'accommodationLocation': accommodationData['Location'] ?? '',
              };
            }
          }
        }
      }

      AppLogger.log('❌ No room found with matching rent: $rentValue');
      return null;
    } catch (e) {
      AppLogger.log('❌ Error finding room by rent: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _findRoomByNumber(String roomNumber) async {
    try {
      AppLogger.log('🔍 Searching for room by number: $roomNumber');

      // Get accommodations from landlord's subcollection
      final accommodationsSnapshot = await _firestore
          .collection('landlords')
          .doc(widget.landlordId)
          .collection('accommodations')
          .get();

      for (final accDoc in accommodationsSnapshot.docs) {
        final accommodationId = accDoc.id;
        final accommodationData = accDoc.data();

        // Search for room by room number
        final roomsSnapshot = await _firestore
            .collection('Accommodations')
            .doc(accommodationId)
            .collection('Rooms')
            .where('RoomNumber', isEqualTo: roomNumber)
            .get();

        if (roomsSnapshot.docs.isNotEmpty) {
          final roomDoc = roomsSnapshot.docs.first;
          final roomData = roomDoc.data();
          AppLogger.log('✅ Found room: ${roomDoc.id}');

          return {
            ...roomData,
            'roomId': roomDoc.id,
            'accommodationId': accommodationId,
            'accommodationName':
                accommodationData['Name'] ?? 'Unknown Accommodation',
            'accommodationLocation': accommodationData['Location'] ?? '',
          };
        }
      }

      AppLogger.log('❌ No room found with number: $roomNumber');
      return null;
    } catch (e) {
      AppLogger.log('❌ Error finding room by number: $e');
      return null;
    }
  }

  // Room linking functionality after lease signing - UPDATED
  Future<void> _linkRoomToStudentAfterLeaseSign(
      String documentId, Map<String, dynamic> leaseData) async {
    try {
      final studentId = widget.studentId;
      final landlordId = widget.landlordId;
      final roomDetails = leaseData['roomDetails'] ?? {};

      AppLogger.log('🔗 Starting room linking process...');
      AppLogger.log('   Student ID: $studentId');
      AppLogger.log('   Landlord ID: $landlordId');

      // Get room details from lease data
      final roomId = roomDetails['roomId'];
      final accommodationId = roomDetails['accommodationId'];
      final roomNumber = roomDetails['RoomNumber'] ?? 'Unknown';

      if (roomId == null || accommodationId == null) {
        AppLogger.log('❌ Missing roomId or accommodationId in lease data');
        throw Exception('Missing room information for assignment');
      }

      AppLogger.log('🔗 Linking room $roomNumber ($roomId) to student $studentId');

      // Store room assignment in StudentRooms
      await _firestore.collection('StudentRooms').doc(studentId).set({
        'RoomID': roomId,
        'AccommodationID': accommodationId,
        'StudentID': studentId,
        'LandlordID': landlordId,
        'LeaseStartDate': FieldValue.serverTimestamp(),
        'IsActive': true,
        'LeaseDocumentId': documentId,
        'RoomDetails': roomDetails,
        'CreatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      AppLogger.log('✅ StudentRooms document created/updated');

      // Update the room status to Occupied
      await _updateRoomStatus(accommodationId, roomId, 'Occupied');

      AppLogger.log('✅ Room $roomNumber linked to student $studentId');

      // Send confirmation message with room details
      await _sendConfirmationMessage(studentId, roomDetails);
    } catch (e) {
      AppLogger.log('❌ Error linking room to student: $e');
      rethrow;
    }
  }

  // Update room status - UPDATED
  Future<void> _updateRoomStatus(
      String accommodationId, String roomId, String status) async {
    try {
      AppLogger.log('🎯 Updating room status to: $status');
      AppLogger.log('   Accommodation: $accommodationId');
      AppLogger.log('   Room: $roomId');

      await _firestore
          .collection('Accommodations')
          .doc(accommodationId)
          .collection('Rooms')
          .doc(roomId)
          .update({
        'AvailabilityStatus': status,
        'UpdatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.log('✅ Room status updated to: $status');
    } catch (e) {
      AppLogger.log('❌ Error updating room status: $e');
      rethrow;
    }
  }

  // Send confirmation with room details
  Future<void> _sendConfirmationMessage(
      String studentId, Map<String, dynamic> roomDetails) async {
    try {
      final messagesRef =
          _firestore.collection('chats').doc(_chatId).collection('messages');

      final roomNumber = roomDetails['RoomNumber'] ?? 'Unknown';
      final accommodationName =
          roomDetails['AccommodationName'] ?? 'Unknown Accommodation';

      final messageText =
          'Lease signed successfully! Room $roomNumber at $accommodationName has been assigned to you. You can now submit maintenance requests from your profile.';

      await messagesRef.add({
        'senderId': widget.landlordId,
        'type': 'system',
        'text': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'isSystemMessage': true,
      });

      await _firestore.collection('chats').doc(_chatId).update({
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.log('❌ Error sending confirmation message: $e');
    }
  }

  // Lease signing with room linking
  Future<void> _updateLeaseStatus(
      String documentId, String status, String transactionHash) async {
    try {
      await _firestore
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .doc(documentId)
          .update({
        'leaseStatus': status,
        'signTransactionHash': transactionHash,
        'signedAt': FieldValue.serverTimestamp(),
      });
      AppLogger.log('✅ Lease status updated to: $status');
    } catch (e) {
      AppLogger.log('❌ Error updating lease status: $e');
      AppLogger.log('⚠️ Continuing with room linking despite status update failure');
    }
  }

  // PDF Preview Method
  Future<void> _previewPDF(Map<String, dynamic> leaseData) async {
    try {
      await _pdfService.previewPDF(leaseData);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to preview PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // HELPER METHODS
  String _getDefaultTerms() {
    return '''1. Rent: As specified in lease, due on the 1st of each month
2. Security Deposit: One month's rent, refundable upon termination
3. Lease Duration: 12 months from start date
4. Utilities: Water and electricity included
5. Internet: Wi-Fi included in rent
6. Maintenance: Landlord responsible for major repairs
7. Cleaning: Student responsible for room cleanliness
8. Quiet Hours: 10:00 PM to 7:00 AM
9. Guests: Overnight guests limited to 2 nights per month with prior notice
10. Pets: Not allowed without written permission
11. Smoking: Strictly prohibited in all areas
12. Termination: 30-day written notice required
13. Late Payment: 5% penalty for rent paid after 5th of month
14. Damages: Student liable for damages beyond normal wear and tear
15. Inspection: Landlord may inspect with 24-hour notice''';
  }

  String _getShortTermTerms() {
    return '''1. Rent: 10% premium for short-term lease
2. Security Deposit: One month's rent
3. Lease Duration: 6 months only
4. Utilities: All included
5. Early Termination: 14-day notice required
6. Renewal: Subject to availability
7. Other terms follow standard agreement''';
  }

  String _getPremiumTerms() {
    return '''1. Rent: 50% premium for premium room features
2. Security Deposit: One month's rent
3. Lease Duration: 12 months
4. Utilities: All included plus weekly cleaning
5. Room Features: En-suite bathroom, premium furniture
6. Maintenance: Priority 24-hour service
7. Other terms follow standard agreement''';
  }

  String _getStudentBlockchainAddress() {
    return '0xStudent${widget.studentId.substring(0, 8)}';
  }

  String _getLandlordPrivateKey() {
    return 'landlord_private_key_${widget.landlordId}';
  }

  String _getStudentPrivateKey() {
    return 'student_private_key_${widget.studentId}';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getMessages() {
    if (_chatId.isEmpty) {
      return const Stream.empty();
    }

    return _firestore
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.landlordName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                )),
            Text(
              'Landlord',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A237E),
        actions: [
          if (_isLandlord)
            IconButton(
              icon: const Icon(Icons.description, color: Colors.white),
              onPressed: _toggleLeaseOptions,
              tooltip: 'Create Lease Agreement',
            ),
          IconButton(
            icon: const Icon(
              Icons.info_outline,
              color: Colors.white,
            ),
            onPressed: _showChatInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          // Lease Options Panel
          if (_showLeaseOptions) _buildLeaseOptions(),

          // Messages List
          Expanded(
            child: _chatId.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Initializing chat...'),
                      ],
                    ),
                  )
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: getMessages(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error,
                                  color: Colors.red, size: 64),
                              const SizedBox(height: 16),
                              const Text(
                                'Error loading messages',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                "No messages yet",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                "Start the conversation!",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final messages = snapshot.data!.docs;
                      final currentUserId = _auth.currentUser?.uid;

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16.0),
                        reverse: false,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final messageDoc = messages[index];
                          final message = messageDoc.data();
                          final senderId = message['senderId'];
                          final messageType = message['type'] ?? 'text';

                          final isMe = senderId == currentUserId;
                          final isLandlord = senderId == widget.landlordId;

                          if (messageType == 'lease_agreement') {
                            return _buildLeaseMessageBubble(
                              message,
                              messageDoc.id,
                              isMe,
                              isLandlord
                                  ? widget.landlordName
                                  : widget.studentName,
                            );
                          } else if (messageType == 'system') {
                            return _buildSystemMessageBubble(message);
                          } else {
                            return _buildMessageBubble(
                              message,
                              isMe,
                              isLandlord
                                  ? widget.landlordName
                                  : widget.studentName,
                              isLandlord,
                            );
                          }
                        },
                      );
                    },
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildLeaseOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lease Agreement Options',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Main Edit & Send Button
          ElevatedButton(
            onPressed: _createAndSendLease,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_document, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Create & Edit Lease',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Quick Template Buttons
          const Text(
            'Quick Templates:',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTemplateButton('Standard 12 Months', _createStandardLease),
              _buildTemplateButton('6 Months Short', _createShortTermLease),
              _buildTemplateButton('Premium Room', _createPremiumLease),
            ],
          ),

          const SizedBox(height: 8),
          const Text(
            'Create a professional PDF lease agreement. You will select a room and can edit all terms before sending.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateButton(String text, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildLeaseMessageBubble(
    Map<String, dynamic> message,
    String documentId,
    bool isMe,
    String senderName,
  ) {
    final isSigned = message['leaseStatus'] == 'signed';
    final ipfsHash = message['ipfsHash'] ?? '';
    final transactionHash = message['transactionHash'] ?? '';
    final leaseData = message['leaseData'] ?? {};
    final isPDF = leaseData['isPDF'] == true;
    final template = leaseData['template'];
    final lastEdited = leaseData['lastEdited'];
    final roomDetails = leaseData['roomDetails'] ?? {};
    final roomNumber = roomDetails['RoomNumber'] ?? 'Selected Room';
    final accommodationName =
        roomDetails['AccommodationName'] ?? 'Accommodation';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Card(
        elevation: 3,
        color: isSigned ? Colors.green[50] : Colors.blue[50],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isPDF ? Icons.picture_as_pdf : Icons.description,
                    color: isSigned ? Colors.green : Colors.blue,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPDF ? 'PDF Lease Agreement' : 'Lease Agreement',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isSigned ? Colors.green : Colors.blue,
                          ),
                        ),
                        if (template != null)
                          Text(
                            'Template: ${_formatTemplateName(template)}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                        Text(
                          '$roomNumber - $accommodationName',
                          style: TextStyle(
                            fontSize: 12,
                            color: isSigned ? Colors.green : Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isPDF)
                    const Icon(Icons.picture_as_pdf,
                        color: Colors.red, size: 20),
                  // In _buildLeaseMessageBubble method, add this after the preview PDF button:
                  if (!isSigned && _isLandlord)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => _resendLeaseWithRoomData(documentId),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.blue),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Resend with Room Data',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ),
                  if (isSigned)
                    const Icon(Icons.verified, color: Colors.green, size: 20),
                ],
              ),
              const SizedBox(height: 12),

              // Show edit info if available
              if (lastEdited != null && _isLandlord)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.orange[700], size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Customized lease',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

              if (lastEdited != null && _isLandlord) const SizedBox(height: 8),

              _buildLeaseDetailRow(
                  'From:', leaseData['landlordName'] ?? 'Landlord'),
              _buildLeaseDetailRow('To:', leaseData['Name'] ?? 'Student'),
              _buildLeaseDetailRow('Room:', '$roomNumber - $accommodationName'),
              _buildLeaseDetailRow('Rent:', leaseData['monthlyRent'] ?? 'R0'),
              _buildLeaseDetailRow(
                  'Duration:', leaseData['leaseDuration'] ?? '12 months'),
              if (isPDF)
                _buildLeaseDetailRow('Format:', 'PDF Document',
                    isHighlighted: true),

              const SizedBox(height: 16),

              // Action Buttons
              if (isPDF && !isSigned)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _previewPDF(leaseData),
                        icon: const Icon(Icons.preview, size: 20),
                        label: const Text('Preview PDF Lease'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),

              if (!isSigned && _auth.currentUser?.uid == widget.studentId)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _signLeaseAgreement(
                        ipfsHash, transactionHash, documentId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Sign Lease Agreement',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),

              if (isSigned)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified, color: Colors.green[800]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Signed and stored on blockchain. $roomNumber has been assigned!',
                          style: TextStyle(
                            color: Colors.green[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),
              if (ipfsHash.isNotEmpty) _buildHashRow('IPFS:', ipfsHash),
              if (transactionHash.isNotEmpty)
                _buildHashRow('Tx:', transactionHash),
            ],
          ),
        ),
      ),
    );
  }

  // FIXED SYSTEM MESSAGE BUBBLE TO PREVENT OVERFLOW
  Widget _buildSystemMessageBubble(Map<String, dynamic> message) {
    final messageText = message['text'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                messageText,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTemplateName(String template) {
    switch (template) {
      case 'standard':
        return 'Standard';
      case 'short_term':
        return 'Short Term';
      case 'premium':
        return 'Premium';
      default:
        return 'Custom';
    }
  }

  Widget _buildLeaseDetailRow(String label, String value,
      {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w400,
              color: isHighlighted ? Colors.green : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHashRow(String label, String hash) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '${hash.substring(0, 16)}...',
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> message,
    bool isMe,
    String senderName,
    bool isFromLandlord,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                backgroundColor: isFromLandlord
                    ? const Color(0xFF1A237E)
                    : Colors.orange.shade700,
                child: Text(
                  senderName.isNotEmpty
                      ? senderName[0].toUpperCase()
                      : isFromLandlord
                          ? 'L'
                          : 'S',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF1A237E) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Text(
                      senderName,
                      style: TextStyle(
                        fontSize: 12,
                        color: isFromLandlord
                            ? const Color(0xFF1A237E)
                            : Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  Text(
                    message['text']?.toString() ?? '',
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(message['timestamp']),
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.grey.shade600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMe)
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: CircleAvatar(
                backgroundColor: Colors.grey.shade300,
                child: Text(
                  widget.studentName.isNotEmpty
                      ? widget.studentName[0].toUpperCase()
                      : 'S',
                  style: const TextStyle(color: Colors.black87),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: "Type a message...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                enabled: !_isSending,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: _isSending ? Colors.grey : const Color(0xFF1A237E),
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: _isSending ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  void _showChatInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chat Info'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chat ID: $_chatId'),
              const SizedBox(height: 10),
              Text('Landlord: ${widget.landlordName} (${widget.landlordId})'),
              const SizedBox(height: 10),
              Text('Student: ${widget.studentName} (${widget.studentId})'),
              const SizedBox(height: 10),
              Text('Current User: ${_auth.currentUser?.uid}'),
              const SizedBox(height: 10),
              Text('User Role: ${_isLandlord ? 'Landlord' : 'Student'}'),
              const SizedBox(height: 10),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      final DateTime time = timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.parse(timestamp.toString());

      final now = DateTime.now();
      final difference = now.difference(time);

      if (difference.inSeconds < 60) {
        return 'Now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${time.day}/${time.month}/${time.year}';
      }
    } catch (e) {
      return '';
    }
  }
}
