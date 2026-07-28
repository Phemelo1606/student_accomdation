import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddAccommodationPage extends StatefulWidget {
  final String landlordId;

  const AddAccommodationPage({super.key, required this.landlordId});

  @override
  _AddAccommodationPageState createState() => _AddAccommodationPageState();
}

class _AddAccommodationPageState extends State<AddAccommodationPage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _capacityController = TextEditingController();
  final _distanceController = TextEditingController();
  final _typeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();

  bool _isLoading = false;

  Future<void> _ensureLandlordDocumentExists() async {
    final landlordDoc =
        await _firestore.collection("landlords").doc(widget.landlordId).get();

    if (!landlordDoc.exists) {
      // Create the landlord document if it doesn't exist
      final currentUser = _auth.currentUser;
      await _firestore.collection("landlords").doc(widget.landlordId).set({
        "landlordID": widget.landlordId,
        "email": currentUser?.email ?? "",
        "name": currentUser?.displayName ?? "Landlord",
        "phoneNumber": "",
        "accommodationName": "",
        "location": "",
        "profileImageUrl": "",
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _saveAccommodation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // First, ensure the landlord document exists
      await _ensureLandlordDocumentExists();

      // Get current user data for landlord info
      final currentUser = _auth.currentUser;
      final landlordDoc =
          await _firestore.collection("landlords").doc(widget.landlordId).get();
      final landlordData = landlordDoc.data();

      // Then save to landlord's accommodations subcollection
      await _firestore
          .collection("landlords")
          .doc(widget.landlordId)
          .collection("accommodations")
          .add({
        // Basic accommodation details (set by landlord)
        "Name": _nameController.text.trim(),
        "Location": _locationController.text.trim(),
        "Capacity": int.tryParse(_capacityController.text.trim()) ?? 0,
        "DistanceFromCampus":
            double.tryParse(_distanceController.text.trim()) ?? 0.0,
        "Type": _typeController.text.trim(),
        "Description": _descriptionController.text.trim(),
        "ContactEmail": _contactEmailController.text.trim().isNotEmpty
            ? _contactEmailController.text.trim()
            : currentUser?.email ?? "",
        "ContactPhone": _contactPhoneController.text.trim(),

        // Landlord information
        "LandlordID": widget.landlordId,
        "LandlordName":
            landlordData?['name'] ?? currentUser?.displayName ?? "Landlord",
        "LandlordEmail": currentUser?.email ?? "",

        // Accreditation fields (set by staff only - initialized as pending)
        "AccreditationStatus": "Pending", // Default status
        "SafetyRating": 0, // Default rating (0 means not rated yet)
        "AccreditationComment": "", // Empty until staff reviews
        "AccreditedBy": "", // Empty until staff accredits
        "AccreditedAt": null, // Empty until staff accredits

        // System fields
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
        "Images": [], // Empty image array for now
        "Amenities": [], // Empty amenities array for now
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Accommodation submitted for review!"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error saving accommodation: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Accommodation",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with info about accreditation process
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          "Accreditation Process",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A237E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Your accommodation will be reviewed by CUT Housing Staff. "
                      "They will assign safety ratings and accreditation status "
                      "after verification.",
                      style: TextStyle(
                        fontSize: 14,
                        color: Color.fromARGB(255, 80, 79, 79),
                      ),
                    ),
                  ],
                ),
              ),

              // Accommodation Name
              _buildTextField(
                controller: _nameController,
                label: "Accommodation Name *",
                hintText: "Enter accommodation name",
                required: true,
                icon: Icons.business,
              ),

              // Location
              _buildTextField(
                controller: _locationController,
                label: "Location *",
                hintText: "Enter full address including street, suburb, city",
                required: true,
                icon: Icons.location_on,
              ),

              // Capacity
              _buildTextField(
                controller: _capacityController,
                label: "Capacity *",
                hintText: "Maximum number of students",
                required: true,
                keyboardType: TextInputType.number,
                icon: Icons.people,
              ),

              // Distance from Campus
              _buildTextField(
                controller: _distanceController,
                label: "Distance from Campus (km) *",
                hintText: "e.g., 2.5",
                required: true,
                keyboardType: TextInputType.number,
                icon: Icons.directions_walk,
              ),

              // Type with dropdown
              _buildDropdownField(),

              // Description
              _buildTextAreaField(
                controller: _descriptionController,
                label: "Description",
                hintText:
                    "Describe your accommodation, facilities, and features...",
                icon: Icons.description,
              ),

              // Contact Email
              _buildTextField(
                controller: _contactEmailController,
                label: "Contact Email",
                hintText: "Email for accommodation inquiries",
                keyboardType: TextInputType.emailAddress,
                icon: Icons.email,
              ),

              // Contact Phone
              _buildTextField(
                controller: _contactPhoneController,
                label: "Contact Phone",
                hintText: "Phone number for accommodation inquiries",
                keyboardType: TextInputType.phone,
                icon: Icons.phone,
              ),

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF1A237E)),
                        ),
                      )
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A237E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _saveAccommodation,
                        child: const Text(
                          "Submit for Review",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: 16),

              // Cancel Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: const BorderSide(color: Color(0xFF1A237E)),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.pop(context);
                        },
                  child: const Text(
                    "Cancel",
                    style: TextStyle(
                      color: Color(0xFF1A237E),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: const OutlineInputBorder(),
          prefixIcon: icon != null ? Icon(icon) : null,
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        validator: required
            ? (value) {
                if (value == null || value.isEmpty) {
                  return 'This field is required';
                }
                if (keyboardType == TextInputType.number &&
                    double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                if (keyboardType == TextInputType.emailAddress &&
                    value.isNotEmpty &&
                    !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildTextAreaField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          border: const OutlineInputBorder(),
          prefixIcon: icon != null ? Icon(icon) : null,
          filled: true,
          fillColor: Colors.grey.shade50,
          alignLabelWithHint: true,
        ),
      ),
    );
  }

  Widget _buildDropdownField() {
    final List<String> accommodationTypes = [
      'Student Residence',
      'Apartment Complex',
      'Shared House',
      'Bachelor Flat',
      'Backroom',
      'Lodge',
      'Other'
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: _typeController.text.isEmpty ? null : _typeController.text,
        decoration: const InputDecoration(
          labelText: "Accommodation Type *",
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.category),
          filled: true,
          fillColor: Color.fromARGB(255, 243, 242, 242),
        ),
        items: accommodationTypes.map((String type) {
          return DropdownMenuItem<String>(
            value: type,
            child: Text(type),
          );
        }).toList(),
        onChanged: (String? newValue) {
          setState(() {
            _typeController.text = newValue ?? '';
          });
        },
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select accommodation type';
          }
          return null;
        },
        hint: const Text('Select accommodation type'),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    _distanceController.dispose();
    _typeController.dispose();
    _descriptionController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }
}
