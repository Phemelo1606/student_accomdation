import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ApplicationFormPage extends StatefulWidget {
  final String roomId;

  const ApplicationFormPage({super.key, required this.roomId});

  @override
  State<ApplicationFormPage> createState() => _ApplicationFormPageState();
}

class _ApplicationFormPageState extends State<ApplicationFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime? _selectedDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _prefillUserDetails();
  }

  Future<void> _prefillUserDetails() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        _nameController.text = "${data['name']} ${data['surname'] ?? ''}";
        _emailController.text = data['email'] ?? user.email ?? '';
        _phoneController.text = data['phoneNumber'] ?? '';
      }
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null) return;

    setState(() => _isSubmitting = true);
    final user = _auth.currentUser;

    try {
      await _firestore.collection('applications').add({
        'studentId': user?.uid,
        'roomId': widget.roomId,
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'moveInDate': _selectedDate,
        'note': _noteController.text.trim(),
        'applicationDate': FieldValue.serverTimestamp(),
        'status': 'Pending',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Application submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickMoveInDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      setState(() => _selectedDate = pickedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF0A0A7E); // CUT blue

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: themeColor,
        title: const Text("Application Form",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Full Name",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(hintText: 'Value'),
                  validator: (v) =>
                      v!.isEmpty ? 'Please enter your name' : null,
                ),
                const SizedBox(height: 16),
                const Text("Email",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(hintText: 'Value'),
                  validator: (v) =>
                      v!.isEmpty ? 'Please enter your email' : null,
                ),
                const SizedBox(height: 16),
                const Text("Phone",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(hintText: 'Value'),
                  validator: (v) =>
                      v!.isEmpty ? 'Please enter your phone number' : null,
                ),
                const SizedBox(height: 16),
                const Text("Move-in Date",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                InkWell(
                  onTap: _pickMoveInDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      hintText: 'Select Move-in Date',
                    ),
                    child: Text(_selectedDate == null
                        ? 'Value'
                        : DateFormat('dd MMM yyyy').format(_selectedDate!)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Note",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextFormField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Value'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isSubmitting ? null : _submitApplication,
                    child: Text(
                      _isSubmitting ? 'Submitting...' : 'Submit Application',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
