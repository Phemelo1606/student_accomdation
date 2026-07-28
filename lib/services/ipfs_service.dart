// services/ipfs_service_pdf.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import './pdf_service.dart';
import '../config/app_config.dart';
import 'package:student_accomdation/core/app_logger.dart';

class PDFIPFSService {
  static const String pinataUrl =
      'https://api.pinata.cloud/pinning/pinFileToIPFS';
  static const String pinataJsonUrl =
      'https://api.pinata.cloud/pinning/pinJSONToIPFS';
  static const String gatewayUrl = 'https://gateway.pinata.cloud/ipfs';

  final PDFService _pdfService = PDFService();

  // Upload PDF file to IPFS
  Future<String> uploadLeasePDFToIPFS(Map<String, dynamic> leaseData) async {
    try {
      AppLogger.log('📤 Generating PDF lease agreement...');

      // Generate PDF file with error handling
      File? pdfFile;
      try {
        pdfFile = await _pdfService.generateLeasePDF(leaseData);
        AppLogger.log('📄 PDF generated: ${pdfFile.path}');
      } catch (pdfError) {
        AppLogger.log('❌ PDF generation error: $pdfError');
        // Fallback to mock
        return _generateMockIPFSHash(leaseData);
      }

      // Check if we should use real IPFS or mock
      if (AppConfig.useMockServices ||
          AppConfig.pinataApiKey.isEmpty ||
          AppConfig.pinataSecretKey.isEmpty) {
        AppLogger.log('🔄 Using mock IPFS service...');
        return _generateMockIPFSHash(leaseData);
      }

      // Upload PDF to IPFS with timeout
      final pdfIpfsHash =
          await _uploadFileToIPFS(pdfFile, 'lease_agreement.pdf');

      // Also upload JSON metadata
      final metadata = {
        ...leaseData,
        'pdfIpfsHash': pdfIpfsHash,
        'pdfUrl': '$gatewayUrl/$pdfIpfsHash',
        'documentType': 'lease_agreement_pdf',
        'createdAt': DateTime.now().toIso8601String(),
      };

      final metadataIpfsHash = await _uploadJSONToIPFS(metadata);

      AppLogger.log('✅ PDF uploaded to IPFS successfully!');
      AppLogger.log('   PDF IPFS Hash: $pdfIpfsHash');
      AppLogger.log('   Metadata IPFS Hash: $metadataIpfsHash');

      return metadataIpfsHash;
    } catch (e) {
      AppLogger.log('❌ PDF IPFS upload error: $e');
      AppLogger.log('🔄 Falling back to mock IPFS service due to error...');
      return _generateMockIPFSHash(leaseData);
    }
  }

  Future<String> _uploadFileToIPFS(File file, String fileName) async {
    try {
      AppLogger.log('📤 Uploading file to IPFS: $fileName');

      final request = http.MultipartRequest('POST', Uri.parse(pinataUrl))
        ..headers.addAll({
          'pinata_api_key': AppConfig.pinataApiKey,
          'pinata_secret_api_key': AppConfig.pinataSecretKey,
        })
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: fileName,
          contentType: MediaType('application', 'pdf'),
        ))
        ..fields['pinataMetadata'] = jsonEncode({
          'name': fileName,
          'keyvalues': {
            'type': 'lease_pdf',
            'app': 'student_accommodation',
            'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          }
        });

      AppLogger.log('📊 Sending request to Pinata...');
      final response =
          await request.send().timeout(const Duration(seconds: 30));
      final responseBody = await response.stream.bytesToString();

      AppLogger.log('📊 Pinata file upload response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final result = jsonDecode(responseBody);
        final ipfsHash = result['IpfsHash'];
        AppLogger.log('✅ File uploaded successfully: $ipfsHash');
        return ipfsHash;
      } else {
        AppLogger.log('❌ Pinata upload failed: ${response.statusCode} - $responseBody');
        throw Exception('Pinata upload failed: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.log('❌ File upload error: $e');
      rethrow;
    }
  }

  Future<String> _uploadJSONToIPFS(Map<String, dynamic> data) async {
    try {
      AppLogger.log('📤 Uploading JSON metadata to IPFS...');

      final response = await http
          .post(
            Uri.parse(pinataJsonUrl),
            headers: {
              'Content-Type': 'application/json',
              'pinata_api_key': AppConfig.pinataApiKey,
              'pinata_secret_api_key': AppConfig.pinataSecretKey,
            },
            body: jsonEncode({
              'pinataContent': data,
              'pinataMetadata': {
                'name':
                    'lease_metadata_${DateTime.now().millisecondsSinceEpoch}',
                'keyvalues': {
                  'type': 'lease_metadata',
                  'app': 'student_accommodation',
                }
              },
            }),
          )
          .timeout(const Duration(seconds: 30));

      AppLogger.log('📊 Pinata JSON upload response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        final ipfsHash = result['IpfsHash'];
        AppLogger.log('✅ JSON metadata uploaded successfully: $ipfsHash');
        return ipfsHash;
      } else {
        AppLogger.log(
            '❌ Pinata JSON upload failed: ${response.statusCode} - ${response.body}');
        throw Exception('Pinata JSON upload failed: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.log('❌ JSON upload error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getLeaseFromIPFS(String ipfsHash) async {
    if (ipfsHash.startsWith('QmMock') || AppConfig.useMockServices) {
      return _getMockLeaseData(ipfsHash);
    }

    try {
      AppLogger.log('📥 Fetching lease from IPFS: $ipfsHash');
      final response = await http.get(Uri.parse('$gatewayUrl/$ipfsHash'));

      if (response.statusCode == 200) {
        final metadata = jsonDecode(response.body);
        AppLogger.log('✅ Lease fetched from IPFS successfully');

        // If it has PDF reference, you can download the PDF too
        if (metadata['pdfIpfsHash'] != null) {
          metadata['pdfDownloadUrl'] = '$gatewayUrl/${metadata['pdfIpfsHash']}';
        }

        return metadata;
      } else {
        throw Exception('Failed to fetch from IPFS: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.log('❌ IPFS fetch error: $e');
      return _getMockLeaseData(ipfsHash);
    }
  }

  String _generateMockIPFSHash(Map<String, dynamic> leaseData) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final landlordName = leaseData['landlordName']?.toString() ?? 'LLD';
    final shortName =
        landlordName.length >= 3 ? landlordName.substring(0, 3) : 'LLD';
    final hash = 'QmMockPDF$timestamp$shortName';
    AppLogger.log('Generated mock IPFS hash: $hash');
    return hash;
  }

  Map<String, dynamic> _getMockLeaseData(String ipfsHash) {
    return {
      'landlordName': 'Josh Cash',
      'studentName': 'Student',
      'monthlyRent': 'R5000',
      'leaseDuration': '12 months',
      'pdfIpfsHash': 'QmMockPDF${DateTime.now().millisecondsSinceEpoch}',
      'pdfUrl': 'https://example.com/mock-lease.pdf',
      'ipfsHash': ipfsHash,
      'isMock': true,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  // Method to verify if the service is working
  Future<bool> testConnection() async {
    try {
      if (AppConfig.useMockServices) {
        AppLogger.log('🔧 Using mock services - connection test skipped');
        return true;
      }

      final testData = {
        'test': true,
        'timestamp': DateTime.now().toIso8601String()
      };
      final response = await http.post(
        Uri.parse(pinataJsonUrl),
        headers: {
          'Content-Type': 'application/json',
          'pinata_api_key': AppConfig.pinataApiKey,
          'pinata_secret_api_key': AppConfig.pinataSecretKey,
        },
        body: jsonEncode({
          'pinataContent': testData,
          'pinataMetadata': {'name': 'connection_test'},
        }),
      );

      final isConnected = response.statusCode == 200;
      AppLogger.log('🔧 Pinata connection test: ${isConnected ? 'SUCCESS' : 'FAILED'}');
      return isConnected;
    } catch (e) {
      AppLogger.log('🔧 Pinata connection test failed: $e');
      return false;
    }
  }
}
