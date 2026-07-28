import 'package:cloud_firestore/cloud_firestore.dart';

Future<String> createOrGetChat(String studentId, String landlordId) async {
  final chatId = '${studentId}_$landlordId'; // unique chat ID
  final chatDoc = FirebaseFirestore.instance.collection('chats').doc(chatId);

  final docSnapshot = await chatDoc.get();

  if (!docSnapshot.exists) {
    // Create the chat document with participants array
    await chatDoc.set({
      'participants': [studentId, landlordId],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  return chatId; // return chatId to use when sending messages
}

Future<void> sendMessage(String chatId, String senderId, String text) async {
  final messagesRef = FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .collection('messages');

  await messagesRef.add({
    'senderId': senderId,
    'text': text,
    'timestamp': FieldValue.serverTimestamp(),
  });
}

Stream<QuerySnapshot> getMessages(String chatId) {
  return FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('timestamp', descending: false)
      .snapshots();
}
