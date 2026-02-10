// Verification Screen - Certificate upload and verification
// lib/features/verification/presentation/verification_screen.dart

// Note: Using XFile instead of dart:io File for cross-platform compatibility
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:convex_flutter/convex_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:quickfit/shared/widgets/adaptive_app_bar.dart';
import 'package:quickfit/core/utils/platform.dart';

class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  final _picker = ImagePicker();
  XFile? _selectedFile;
  bool _isUploading = false;
  String? _verificationStatus; // 'pending', 'verified', 'rejected'

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedFile = image;
      });
    }
  }

  Future<void> _takePhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _selectedFile = image;
      });
    }
  }

  Future<void> _uploadCertificate() async {
    if (_selectedFile == null) return;

    setState(() => _isUploading = true);

    try {
      // 1. Get an upload URL from Convex
      final uploadUrlResult = await ConvexClient.instance.mutation(
        name: 'storage:generateUploadUrl',
        args: {},
      );

      final uploadUrl = uploadUrlResult.replaceAll('"', '');
      if (uploadUrl.isEmpty || uploadUrl == 'null') {
        throw Exception('Failed to get upload URL');
      }

      // 2. Read file bytes
      final bytes = await _selectedFile!.readAsBytes();
      final mimeType = _selectedFile!.mimeType ?? 'image/jpeg';

      // 3. Upload to Convex storage
      final uploadResponse = await http.post(
        Uri.parse(uploadUrl),
        headers: {'Content-Type': mimeType},
        body: bytes,
      );

      if (uploadResponse.statusCode != 200) {
        throw Exception('Upload failed: ${uploadResponse.statusCode}');
      }

      final uploadResult = json.decode(uploadResponse.body);
      final storageId = uploadResult['storageId'] as String;

      // 4. Register ownership of uploaded file
      await ConvexClient.instance.mutation(
        name: 'storage:registerUploadedFile',
        args: {
          'storageId': storageId,
          'purpose': 'verification_certificate',
        },
      );

      // 5. Create verification record (triggers Gemini AI verification)
      await ConvexClient.instance.mutation(
        name: 'verifications:uploadCertificate',
        args: {
          'storageId': storageId,
          'docType': mimeType,
          'originalFilename': _selectedFile!.name,
        },
      );

      if (mounted) {
        setState(() {
          _isUploading = false;
          _verificationStatus = 'pending';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(LucideIcons.checkCircle2, color: Colors.white),
                SizedBox(width: 8),
                Text('Certificate uploaded! AI verification in progress...'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: adaptiveAppBar(
        context,
        title: 'Verify Certification',
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header info
            _buildInfoCard(),
            const SizedBox(height: 24),

            // Upload section
            const Text(
              'Upload Certificate',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload a clear photo of your fitness instructor certification (Wingate, IFA, or equivalent).',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),

            // File picker or preview
            if (_selectedFile == null) _buildUploadArea() else _buildPreview(),

            const SizedBox(height: 24),

            // Verification status
            if (_verificationStatus != null) _buildStatusCard(),

            // Upload button
            if (_selectedFile != null && _verificationStatus == null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: isCupertinoPlatform(context)
                    ? CupertinoButton.filled(
                        onPressed: _isUploading ? null : _uploadCertificate,
                        child: _isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.upload, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Submit for Verification',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      )
                    : FilledButton(
                        onPressed: _isUploading ? null : _uploadCertificate,
                        child: _isUploading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(LucideIcons.upload, size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Submit for Verification',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
              ),
            ],

            const SizedBox(height: 32),

            // Requirements
            _buildRequirements(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.info, color: Colors.blue[600], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why verify?',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Verified instructors get priority in job matching and can charge higher rates. Studios trust verified profiles more.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadArea() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[300]!,
          style: BorderStyle.solid,
        ),
      ),
      child: InkWell(
        onTap: () => _showPickerOptions(),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.upload,
                size: 32,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tap to upload certificate',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'JPG, PNG or PDF • Max 10MB',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.image, color: Colors.blue[600]),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.camera, color: Colors.green[600]),
                ),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Stack(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.grey[200],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              _selectedFile!.path,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.file, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      _selectedFile!.name,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () => setState(() => _selectedFile = null),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.x,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    Color bgColor;
    Color borderColor;
    Color iconColor;
    IconData icon;
    String title;
    String subtitle;

    switch (_verificationStatus) {
      case 'verified':
        bgColor = Colors.green[50]!;
        borderColor = Colors.green[200]!;
        iconColor = Colors.green[600]!;
        icon = LucideIcons.badgeCheck;
        title = 'Verified!';
        subtitle = 'Your certification has been verified successfully.';
        break;
      case 'rejected':
        bgColor = Colors.red[50]!;
        borderColor = Colors.red[200]!;
        iconColor = Colors.red[600]!;
        icon = LucideIcons.xCircle;
        title = 'Verification Failed';
        subtitle =
            'We couldn\'t verify your certificate. Please upload a clearer image.';
        break;
      default:
        bgColor = Colors.orange[50]!;
        borderColor = Colors.orange[200]!;
        iconColor = Colors.orange[600]!;
        icon = LucideIcons.clock;
        title = 'Verification Pending';
        subtitle =
            'We\'re reviewing your certificate. This usually takes a few minutes.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: iconColor.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirements() {
    final requirements = [
      'Certificate must be clearly readable',
      'Your name must be visible on the certificate',
      'Certificate must be from a recognized institution',
      'Expiry date (if applicable) must be visible',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Requirements',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        ...requirements.map((req) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    LucideIcons.check,
                    size: 16,
                    color: Colors.green[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      req,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}
