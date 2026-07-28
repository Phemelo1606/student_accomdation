import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:student_accomdation/pages/landlordProfile.dart';
import 'package:student_accomdation/pages/studentProfile.dart';

class ProfileRouter extends StatelessWidget {
  const ProfileRouter({super.key});

  Future<String?> getUserRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final snap =
        await FirebaseFirestore.instance.collection('Users').doc(uid).get();
    return snap.data()?['role'];
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: getUserRole(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final role = snapshot.data;
        if (role == "student") {
          return const StudentProfileScreen();
        } else if (role == "landlord") {
          return LandlordProfileScreen();
        } else {
          return const Scaffold(body: Center(child: Text("Unknown role")));
        }
      },
    );
  }
}
