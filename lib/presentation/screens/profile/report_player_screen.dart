import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/core/utils/storage_service.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';

class ReportPlayerScreen extends StatefulWidget {
  final String? initialMatchTitle;

  const ReportPlayerScreen({super.key, this.initialMatchTitle});

  @override
  State<ReportPlayerScreen> createState() => _ReportPlayerScreenState();
}

class _ReportPlayerScreenState extends State<ReportPlayerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _playerNameController = TextEditingController();
  final _ffIdController = TextEditingController();
  final _matchTitleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedReason = 'Aimbot / Auto Headshot';
  final List<String> _reasons = [
    'Aimbot / Auto Headshot',
    'Wallhack / ESP',
    'Speed Hack / High Movement',
    'Teaming / Collusion',
    'Abusive Behavior / Chat',
    'Other Cheating / Hack',
  ];

  File? _proofImage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialMatchTitle != null && widget.initialMatchTitle!.isNotEmpty) {
      _matchTitleController.text = widget.initialMatchTitle!;
    }
  }

  @override
  void dispose() {
    _playerNameController.dispose();
    _ffIdController.dispose();
    _matchTitleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() {
        _proofImage = File(picked.path);
      });
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_proofImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select a screenshot proof image! 📸"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.userModel;

      // Upload image to ImgBB / Storage
      final storageService = StorageService();
      final imageUrl = await storageService.uploadImage('reports', _proofImage!);

      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception("Failed to upload screenshot proof. Please try again.");
      }

      // Save report to Firestore
      await FirebaseFirestore.instance.collection('reports').add({
        'reportedPlayerName': _playerNameController.text.trim(),
        'reportedFreeFireId': _ffIdController.text.trim(),
        'reportedUserId': '', // Optional if user search is added later
        'reportedBy': user?.uid ?? 'anonymous',
        'reportedByName': user?.name ?? 'Unknown User',
        'matchTitle': _matchTitleController.text.trim(),
        'reason': _selectedReason,
        'description': _descriptionController.text.trim(),
        'proofImageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Report submitted successfully! Admin will review it soon. 🚨"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error submitting report: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Report Player / Cheater 🚨"),
        backgroundColor: AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withOpacity(0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Submit proof against cheaters or bad behavior. False reporting may result in account penalty.",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Player Name
              const Text("Reported Player In-Game Name", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _playerNameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Enter player name e.g. OP_KILLER_99",
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: AppColors.surface,
                  prefixIcon: const Icon(Icons.person, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Please enter player name" : null,
              ),
              const SizedBox(height: 16),

              // Free Fire ID / UID
              const Text("Reported Player Free Fire ID (UID)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _ffIdController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Enter FF UID e.g. 1234567890",
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: AppColors.surface,
                  prefixIcon: const Icon(Icons.badge, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Please enter Free Fire ID" : null,
              ),
              const SizedBox(height: 16),

              // Match / Tournament Name
              const Text("Tournament / Match Name", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _matchTitleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "e.g. Daily Solo Clash Cup #12",
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: AppColors.surface,
                  prefixIcon: const Icon(Icons.sports_esports, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? "Please enter match name" : null,
              ),
              const SizedBox(height: 16),

              // Cheat / Violation Type
              const Text("Reason for Report", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedReason,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surface,
                  prefixIcon: const Icon(Icons.report_problem, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedReason = val);
                },
              ),
              const SizedBox(height: 16),

              // Description
              const Text("Additional Details", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Describe what happened during the match...",
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),

              // Proof Image Picker
              const Text("Proof Image (Screenshot) *", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _proofImage != null ? AppColors.primary : Colors.white24, width: 1.5),
                  ),
                  child: _proofImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(_proofImage!, fit: BoxFit.cover),
                              Positioned(
                                right: 8,
                                top: 8,
                                child: CircleAvatar(
                                  backgroundColor: Colors.black.withOpacity(0.7),
                                  child: IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                                    onPressed: _pickImage,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 40, color: AppColors.primary),
                            SizedBox(height: 8),
                            Text("Tap to upload screenshot proof", style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 30),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitReport,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.black),
                  label: Text(
                    _isSubmitting ? "Submitting..." : "SUBMIT REPORT",
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
