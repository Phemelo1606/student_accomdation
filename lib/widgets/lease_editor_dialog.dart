// widgets/lease_editor_dialog.dart
import 'package:flutter/material.dart';
import 'package:student_accomdation/core/app_logger.dart';

class LeaseEditorDialog extends StatefulWidget {
  final Map<String, dynamic> initialLeaseData;
  final String landlordName;
  final String studentName;

  const LeaseEditorDialog({
    super.key,
    required this.initialLeaseData,
    required this.landlordName,
    required this.studentName,
  });

  @override
  _LeaseEditorDialogState createState() => _LeaseEditorDialogState();
}

class _LeaseEditorDialogState extends State<LeaseEditorDialog> {
  late TextEditingController _monthlyRentController;
  late TextEditingController _leaseDurationController;
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;
  late TextEditingController _locationController;
  late TextEditingController _roomTypeController;
  late TextEditingController _termsController;

  @override
  void initState() {
    super.initState();
    final leaseData = widget.initialLeaseData;
    final roomDetails = leaseData['roomDetails'] ?? {};

    _monthlyRentController =
        TextEditingController(text: leaseData['monthlyRent'] ?? 'R5000');
    _leaseDurationController =
        TextEditingController(text: leaseData['leaseDuration'] ?? '12 months');
    _startDateController =
        TextEditingController(text: _formatDate(leaseData['startDate']));
    _endDateController =
        TextEditingController(text: _formatDate(leaseData['endDate']));
    _locationController = TextEditingController(
        text: roomDetails['location'] ?? 'Campus Accommodation');
    _roomTypeController =
        TextEditingController(text: roomDetails['roomType'] ?? 'Single Room');
    _termsController = TextEditingController(
        text: leaseData['termsAndConditions'] ?? _getDefaultTerms());
  }

  @override
  void dispose() {
    _monthlyRentController.dispose();
    _leaseDurationController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _locationController.dispose();
    _roomTypeController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Select date';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _getDefaultTerms() {
    return '''1. Rent: R5000 per month, due on the 1st of each month
2. Security Deposit: One month's rent (R5000), refundable upon termination
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

  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text = '${picked.day}/${picked.month}/${picked.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A237E),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_document, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'Edit Lease Agreement',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information
                    _buildSectionHeader('Basic Information'),
                    _buildTextField(
                      controller: _monthlyRentController,
                      label: 'Monthly Rent',
                      hint: 'R5000',
                      icon: Icons.attach_money,
                    ),
                    _buildTextField(
                      controller: _leaseDurationController,
                      label: 'Lease Duration',
                      hint: '12 months',
                      icon: Icons.calendar_today,
                    ),

                    // Dates
                    _buildSectionHeader('Lease Dates'),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateField(
                            controller: _startDateController,
                            label: 'Start Date',
                            onTap: () =>
                                _selectDate(context, _startDateController),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDateField(
                            controller: _endDateController,
                            label: 'End Date',
                            onTap: () =>
                                _selectDate(context, _endDateController),
                          ),
                        ),
                      ],
                    ),

                    // Property Details
                    _buildSectionHeader('Property Details'),
                    _buildTextField(
                      controller: _locationController,
                      label: 'Location',
                      hint: 'Campus Accommodation',
                      icon: Icons.location_on,
                    ),
                    _buildTextField(
                      controller: _roomTypeController,
                      label: 'Room Type',
                      hint: 'Single Room',
                      icon: Icons.room_preferences,
                    ),

                    // Terms and Conditions
                    _buildSectionHeader('Terms and Conditions'),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _termsController,
                        maxLines: 12,
                        decoration: const InputDecoration(
                          hintText: 'Enter lease terms and conditions...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You can modify the standard terms above',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Footer Buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final editedLease = _getEditedLeaseData();
                        Navigator.pop(context, editedLease);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Save & Send',
                        style: TextStyle(color: Colors.white),
                      ),
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1A237E),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: Colors.grey.shade500),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today,
                    color: Colors.grey.shade500, size: 20),
                const SizedBox(width: 12),
                Text(
                  controller.text.isEmpty ? 'Select date' : controller.text,
                  style: TextStyle(
                    color: controller.text.isEmpty
                        ? Colors.grey.shade500
                        : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _getEditedLeaseData() {
    return {
      'landlordName': widget.landlordName,
      'studentName': widget.studentName,
      'monthlyRent': _monthlyRentController.text,
      'leaseDuration': _leaseDurationController.text,
      'startDate': _parseDate(_startDateController.text),
      'endDate': _parseDate(_endDateController.text),
      'termsAndConditions': _termsController.text,
      'roomDetails': {
        'location': _locationController.text,
        'roomType': _roomTypeController.text,
        'monthlyRent': _monthlyRentController.text,
      },
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'sent',
      'lastEdited': DateTime.now().toIso8601String(),
    };
  }

  String _parseDate(String dateText) {
    try {
      final parts = dateText.split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day).toIso8601String();
      }
    } catch (e) {
      AppLogger.log('Date parsing error: $e');
    }
    // Fallback: 30 days from now
    return DateTime.now().add(const Duration(days: 30)).toIso8601String();
  }
}
