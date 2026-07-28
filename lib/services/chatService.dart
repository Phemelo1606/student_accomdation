// Global startChat function
import 'package:flutter/material.dart';
import 'package:student_accomdation/pages/chatScreen.dart';
import 'package:student_accomdation/core/app_logger.dart';

void startChat({
  required BuildContext context,
  required String studentId,
  required String studentName,
  required String landlordId,
  required String landlordName,
}) {
  AppLogger.log('🎯 startChat function called with:');
  AppLogger.log('   Student: $studentName ($studentId)');
  AppLogger.log('   Landlord: $landlordName ($landlordId)');

  if (landlordId.isEmpty || landlordId == 'unknown_landlord') {
    AppLogger.log('❌ ERROR: Invalid landlordId: $landlordId');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Cannot start chat: Invalid landlord information"),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  if (studentId.isEmpty) {
    AppLogger.log('❌ ERROR: Invalid studentId: $studentId');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Cannot start chat: Invalid student information"),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  try {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          landlordId: landlordId,
          landlordName: landlordName,
          studentId: studentId,
          studentName: studentName,
        ),
      ),
    );
    AppLogger.log('✅ ChatScreen navigation successful');
  } catch (e) {
    AppLogger.log('❌ ERROR during navigation: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Error starting chat: $e"),
        backgroundColor: Colors.red,
      ),
    );
  }
}
