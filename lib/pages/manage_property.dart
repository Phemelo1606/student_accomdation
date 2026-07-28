// manage_property_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:student_accomdation/pages/manage_rooms.dart';

class ManagePropertyPage extends StatefulWidget {
  final String accommodationId;
  final String landlordId;

  const ManagePropertyPage({
    super.key,
    required this.accommodationId,
    required this.landlordId,
  });

  @override
  _ManagePropertyPageState createState() => _ManagePropertyPageState();
}

class _ManagePropertyPageState extends State<ManagePropertyPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();
  final TextEditingController _accreditationController =
      TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Additional fields
  bool _isAvailable = true;
  List<String> _amenities = [];
  final TextEditingController _amenityController = TextEditingController();

  // FIX: Safety rating as int (not string)
  int _safetyRating = 0;

  @override
  void initState() {
    super.initState();
    _loadAccommodationData();
  }

  Future<void> _loadAccommodationData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("landlords")
          .doc(widget.landlordId)
          .collection("accommodations")
          .doc(widget.accommodationId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data["Name"]?.toString() ?? "";
          _locationController.text = data["Location"]?.toString() ?? "";
          _capacityController.text = data["Capacity"]?.toString() ?? "";
          _distanceController.text =
              data["DistanceFromCampus"]?.toString() ?? "";

          // FIX: Handle safety rating as int
          _safetyRating =
              data["SafetyRating"] is int ? data["SafetyRating"] as int : 0;

          _typeController.text = data["Type"]?.toString() ?? "";
          _accreditationController.text =
              data["AccreditationStatus"]?.toString() ?? "Pending";
          _priceController.text = data["Price"]?.toString() ?? "";
          _descriptionController.text = data["Description"]?.toString() ?? "";
          _isAvailable = data["Available"] ?? true;
          _amenities = List<String>.from(data["Amenities"] ?? []);
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Accommodation not found"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading data: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateAccommodation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection("landlords")
          .doc(widget.landlordId)
          .collection("accommodations")
          .doc(widget.accommodationId)
          .update({
        "Name": _nameController.text.trim(),
        "Location": _locationController.text.trim(),
        "Capacity": int.tryParse(_capacityController.text.trim()) ?? 0,
        "DistanceFromCampus":
            double.tryParse(_distanceController.text.trim()) ?? 0.0,
        // FIX: Safety rating remains as int (landlords can't change this)
        "Type": _typeController.text.trim(),
        // FIX: Accreditation status remains unchanged (landlords can't change this)
        "Price": double.tryParse(_priceController.text.trim()) ?? 0.0,
        "Description": _descriptionController.text.trim(),
        "Available": _isAvailable,
        "Amenities": _amenities,
        "updatedAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Accommodation updated successfully"),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _isEditing = false;
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error updating accommodation: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteAccommodation() async {
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text(
            "Are you sure you want to delete this accommodation? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isSaving = true);

      try {
        await FirebaseFirestore.instance
            .collection("landlords")
            .doc(widget.landlordId)
            .collection("accommodations")
            .doc(widget.accommodationId)
            .delete();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Accommodation deleted successfully"),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context); // Go back to home page
      } catch (e) {
        if (!mounted) return;

        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error deleting accommodation: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addAmenity() {
    final amenity = _amenityController.text.trim();
    if (amenity.isNotEmpty && !_amenities.contains(amenity)) {
      setState(() {
        _amenities.add(amenity);
        _amenityController.clear();
      });
    }
  }

  void _removeAmenity(String amenity) {
    setState(() {
      _amenities.remove(amenity);
    });
  }

  void _cancelEditing() {
    setState(() => _isEditing = false);
    _loadAccommodationData(); // Reload original data
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Property",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isEditing && !_isLoading)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: "Edit Property",
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _cancelEditing,
              tooltip: "Cancel Editing",
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A237E)),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Status
                    _buildPropertyHeader(),
                    const SizedBox(height: 20),

                    // Basic Information Section
                    _buildSectionHeader("Basic Information"),
                    _buildEditableField(
                      controller: _nameController,
                      label: "Accommodation Name",
                      isEditable: _isEditing,
                      icon: Icons.business,
                    ),
                    _buildEditableField(
                      controller: _locationController,
                      label: "Location",
                      isEditable: _isEditing,
                      icon: Icons.location_on,
                    ),
                    _buildEditableField(
                      controller: _typeController,
                      label: "Type",
                      isEditable: _isEditing,
                      icon: Icons.category,
                    ),

                    // Details Section
                    _buildSectionHeader("Details"),
                    _buildEditableField(
                      controller: _capacityController,
                      label: "Capacity",
                      keyboardType: TextInputType.number,
                      isEditable: _isEditing,
                      icon: Icons.people,
                    ),
                    _buildEditableField(
                      controller: _distanceController,
                      label: "Distance from Campus (km)",
                      keyboardType: TextInputType.number,
                      isEditable: _isEditing,
                      icon: Icons.directions_walk,
                    ),
                    _buildEditableField(
                      controller: _priceController,
                      label: "Monthly Price (\$)",
                      keyboardType: TextInputType.number,
                      isEditable: _isEditing,
                      icon: Icons.attach_money,
                    ),

                    // Ratings & Status (Read-only for landlords)
                    _buildSectionHeader("Accreditation & Safety"),
                    _buildReadOnlyField(
                      label: "Safety Rating",
                      value: _safetyRating > 0
                          ? "$_safetyRating/5 ⭐"
                          : "Not rated yet",
                      icon: Icons.security,
                    ),
                    _buildReadOnlyField(
                      label: "Accreditation Status",
                      value: _accreditationController.text.isNotEmpty
                          ? _accreditationController.text
                          : "Pending Review",
                      icon: Icons.verified,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[100]!),
                      ),
                      child: const Text(
                        "Safety rating and accreditation status are set by CUT Housing Staff during the review process.",
                        style: TextStyle(
                            fontSize: 12,
                            color: Color.fromARGB(255, 21, 101, 192)),
                      ),
                    ),

                    // Availability Toggle
                    if (_isEditing)
                      Card(
                        child: SwitchListTile(
                          title: const Text("Available for Booking"),
                          subtitle: const Text(
                              "Toggle to make property available/unavailable"),
                          value: _isAvailable,
                          onChanged: (value) =>
                              setState(() => _isAvailable = value),
                          secondary: const Icon(Icons.event_available),
                        ),
                      ),

                    // Description
                    _buildSectionHeader("Description"),
                    _buildEditableField(
                      controller: _descriptionController,
                      label: "Description",
                      maxLines: 3,
                      isEditable: _isEditing,
                      icon: Icons.description,
                    ),

                    // Amenities
                    _buildSectionHeader("Amenities"),
                    if (_isEditing) _buildAmenitiesEditor(),
                    if (!_isEditing) _buildAmenitiesList(),

                    const SizedBox(height: 24),

                    // Rooms Management Section
                    _buildSectionHeader("Room Management"),
                    Card(
                      elevation: 2,
                      child: ListTile(
                        leading: const Icon(Icons.meeting_room,
                            color: Color(0xFF1A237E)),
                        title: const Text("Manage Rooms"),
                        subtitle: const Text(
                            "Add, edit, or remove rooms in this property"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ManageRoomsPage(
                                accommodationId: widget.accommodationId,
                                landlordId: widget.landlordId,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action Buttons
                    if (_isEditing) _buildEditActionButtons(),
                    if (!_isEditing) _buildViewActionButtons(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPropertyHeader() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _isAvailable ? Icons.check_circle : Icons.cancel,
              color: _isAvailable ? Colors.green : Colors.red,
              size: 40,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nameController.text.isEmpty
                        ? "Unnamed Property"
                        : _nameController.text,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _locationController.text.isEmpty
                        ? "No location specified"
                        : _locationController.text,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isAvailable ? "Available for Booking" : "Not Available",
                    style: TextStyle(
                      color: _isAvailable ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Accreditation: ${_accreditationController.text.isEmpty ? "Pending" : _accreditationController.text}",
                    style: TextStyle(
                      color: _getStatusColor(
                          _accreditationController.text.isEmpty
                              ? "Pending"
                              : _accreditationController.text),
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A237E),
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    required bool isEditable,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: isEditable
          ? TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                prefixIcon: icon != null ? Icon(icon) : null,
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              keyboardType: keyboardType,
              maxLines: maxLines,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please enter $label";
                }
                if (keyboardType == TextInputType.number &&
                    double.tryParse(value) == null) {
                  return "Please enter a valid number";
                }
                return null;
              },
            )
          : Card(
              elevation: 1,
              child: ListTile(
                leading: icon != null
                    ? Icon(icon, color: const Color(0xFF1A237E))
                    : null,
                title: Text(
                  controller.text.isEmpty ? "Not specified" : controller.text,
                  style: TextStyle(
                    color:
                        controller.text.isEmpty ? Colors.grey : Colors.black87,
                  ),
                ),
                subtitle: Text(label),
              ),
            ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Card(
        elevation: 1,
        child: ListTile(
          leading:
              icon != null ? Icon(icon, color: const Color(0xFF1A237E)) : null,
          title: Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
            ),
          ),
          subtitle: Text(label),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  Widget _buildAmenitiesEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _amenityController,
                decoration: const InputDecoration(
                  labelText: "Add Amenity",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.add_circle_outline),
                ),
                onSubmitted: (_) => _addAmenity(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _addAmenity,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text("Add"),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          "Amenities (${_amenities.length})",
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _amenities
              .map((amenity) => Chip(
                    label: Text(amenity),
                    onDeleted: () => _removeAmenity(amenity),
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ))
              .toList(),
        ),
        if (_amenities.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "No amenities added yet",
              style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }

  Widget _buildAmenitiesList() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _amenities
          .map((amenity) => Chip(
                label: Text(amenity),
                backgroundColor: const Color(0xFF1A237E).withOpacity(0.1),
                labelStyle: const TextStyle(color: Color(0xFF1A237E)),
              ))
          .toList(),
    );
  }

  Widget _buildEditActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: _isSaving
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF1A237E)),
                  ),
                )
              : ElevatedButton(
                  onPressed: _updateAccommodation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Save Changes",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: _isSaving ? null : _cancelEditing,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: const BorderSide(color: Colors.grey),
            ),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => setState(() => _isEditing = true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit, size: 20),
                SizedBox(width: 8),
                Text(
                  "Edit Property",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _deleteAccommodation,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isSaving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Delete Property",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    _distanceController.dispose();
    _typeController.dispose();
    _accreditationController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _amenityController.dispose();
    super.dispose();
  }
}
