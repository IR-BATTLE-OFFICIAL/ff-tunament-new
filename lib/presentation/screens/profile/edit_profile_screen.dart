import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';

import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _ffUidController;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    _nameController = TextEditingController(text: user?.name);
    _phoneController = TextEditingController(text: user?.phone);
    _ffUidController = TextEditingController(text: user?.ffUid);
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _ffUidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;
    
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.surface,
                  backgroundImage: _imageFile != null 
                    ? FileImage(_imageFile!) 
                    : (user?.profilePic != null && user!.profilePic!.isNotEmpty 
                        ? NetworkImage(user.profilePic!) as ImageProvider 
                        : null),
                  child: (_imageFile == null && (user?.profilePic == null || user!.profilePic!.isEmpty))
                    ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey)
                    : null,
                ),
              ),
              const SizedBox(height: 10),
              const Text("Tap to change profile picture", style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 30),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Free Fire Name"),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: "Phone Number"),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _ffUidController,
                decoration: const InputDecoration(labelText: "Free Fire UID"),
              ),
              const SizedBox(height: 30),
              if (authProvider.isLoading)
                const CircularProgressIndicator()
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        try {
                          Map<String, dynamic> data = {
                            'name': _nameController.text,
                            'phone': _phoneController.text,
                            'ffUid': _ffUidController.text,
                          };
                          
                          await authProvider.updateProfile(data, imageFile: _imageFile);
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Profile updated successfully!")),
                            );
                            Navigator.pop(context);
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Error: $e")),
                          );
                        }
                      }
                    },
                    child: const Text("Save Changes"),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
