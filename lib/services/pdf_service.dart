// services/pdf_service.dart
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

class PDFService {
  final pw.Font _boldFont = pw.Font.helveticaBold();
  final pw.Font _regularFont = pw.Font.helvetica();

  Future<File> generateLeasePDF(Map<String, dynamic> leaseData) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return _buildLeaseDocument(leaseData);
        },
      ),
    );

    // Save to temporary directory
    final output = await getTemporaryDirectory();
    final file = File(
        "${output.path}/lease_agreement_${DateTime.now().millisecondsSinceEpoch}.pdf");

    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _buildLeaseDocument(Map<String, dynamic> leaseData) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        _buildHeader(leaseData),
        pw.SizedBox(height: 20),

        // Parties Section
        _buildPartiesSection(leaseData),
        pw.SizedBox(height: 20),

        // Property Details
        _buildPropertySection(leaseData),
        pw.SizedBox(height: 20),

        // Terms and Conditions
        _buildTermsSection(leaseData),
        pw.SizedBox(height: 20),

        // Signatures
        _buildSignatureSection(leaseData),

        // Footer
        pw.Spacer(),
        _buildFooter(leaseData),
      ],
    );
  }

  pw.Widget _buildHeader(Map<String, dynamic> leaseData) {
    return pw.Column(
      children: [
        pw.Text(
          'LEASE AGREEMENT',
          style: pw.TextStyle(
            font: _boldFont,
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Student Accommodation',
          style: pw.TextStyle(
            font: _regularFont,
            fontSize: 16,
            color: PdfColors.grey700,
          ),
        ),
        pw.Divider(thickness: 2),
      ],
    );
  }

  pw.Widget _buildPartiesSection(Map<String, dynamic> leaseData) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PARTIES',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'LANDLORD',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(leaseData['landlordName'] ?? 'Not specified'),
                  pw.Text('ID: ${leaseData['landlordId'] ?? 'N/A'}'),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'STUDENT/TENANT',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(leaseData['studentName'] ?? 'Not specified'),
                  pw.Text('ID: ${leaseData['studentId'] ?? 'N/A'}'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPropertySection(Map<String, dynamic> leaseData) {
    final roomDetails = leaseData['roomDetails'] ?? {};
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'PROPERTY DETAILS',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(),
          children: [
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8.0),
                  child: pw.Text('Monthly Rent',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8.0),
                  child: pw.Text(leaseData['monthlyRent'] ?? 'Not specified'),
                ),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8.0),
                  child: pw.Text('Lease Duration',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8.0),
                  child: pw.Text(leaseData['leaseDuration'] ?? '12 months'),
                ),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8.0),
                  child: pw.Text('Start Date',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8.0),
                  child: pw.Text(_formatDate(leaseData['startDate'])),
                ),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8.0),
                  child: pw.Text('End Date',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8.0),
                  child: pw.Text(_formatDate(leaseData['endDate'])),
                ),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8.0),
                  child: pw.Text('Location',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8.0),
                  child: pw.Text(roomDetails['location'] ?? 'Not specified'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTermsSection(Map<String, dynamic> leaseData) {
    final terms = leaseData['termsAndConditions'] ?? '';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'TERMS AND CONDITIONS',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          terms,
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  pw.Widget _buildSignatureSection(Map<String, dynamic> leaseData) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'SIGNATURES',
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              children: [
                pw.Text('Landlord Signature'),
                pw.SizedBox(height: 40),
                pw.Container(
                  width: 200,
                  height: 1,
                  color: PdfColors.black,
                ),
                pw.SizedBox(height: 5),
                pw.Text(leaseData['landlordName'] ?? 'Landlord'),
                pw.Text(
                    'Date: ${_formatDate(DateTime.now().toIso8601String())}'),
              ],
            ),
            pw.Column(
              children: [
                pw.Text('Student/Tenant Signature'),
                pw.SizedBox(height: 40),
                pw.Container(
                  width: 200,
                  height: 1,
                  color: PdfColors.black,
                ),
                pw.SizedBox(height: 5),
                pw.Text(leaseData['studentName'] ?? 'Student'),
                pw.Text('Date: ___________________'),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildFooter(Map<String, dynamic> leaseData) {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.Text(
          'Document ID: ${leaseData['ipfsHash'] ?? 'Pending IPFS Upload'}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
        ),
        pw.Text(
          'Blockchain Tx: ${leaseData['transactionHash'] ?? 'Pending Blockchain'}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
        ),
        pw.Text(
          'Generated on: ${_formatDate(DateTime.now().toIso8601String())}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
        ),
      ],
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Not specified';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  // Method to preview PDF
  Future<void> previewPDF(Map<String, dynamic> leaseData) async {
    final file = await generateLeasePDF(leaseData);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => file.readAsBytes(),
    );
  }

  // Method to share PDF
  Future<File> getPDFFile(Map<String, dynamic> leaseData) async {
    return await generateLeasePDF(leaseData);
  }
}
