import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ff_arena/core/utils/storage_service.dart';
import 'dart:io';
import 'package:ff_arena/data/models/tournament_model.dart';

class ManageBannersScreen extends StatefulWidget {
  const ManageBannersScreen({super.key});

  @override
  State<ManageBannersScreen> createState() => _ManageBannersScreenState();
}

class _ManageBannersScreenState extends State<ManageBannersScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TournamentProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Manage Banners")),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: provider.banners(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final banners = snapshot.data ?? [];
          return ListView.builder(
            itemCount: banners.length,
            itemBuilder: (context, index) {
              final banner = banners[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      banner['url'], 
                      width: 80, 
                      height: 50, 
                      fit: BoxFit.cover, 
                      errorBuilder: (_,__,___) => const Icon(Icons.broken_image)
                    ),
                  ),
                  title: Text(banner['title'] ?? 'No Title'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Target: ${banner['target'] ?? 'none'}"),
                      if (banner['target'] == 'tournament' && banner['tournamentId'] != null)
                        Text("Tournament ID: ${banner['tournamentId']}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: AppColors.primary),
                        onPressed: () => _showBannerDialog(context, provider, banner),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(context, provider, banner['id']),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBannerDialog(context, provider, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _confirmDelete(BuildContext context, TournamentProvider provider, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Banner?"),
        content: const Text("Are you sure you want to delete this banner?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await provider.deleteBanner(id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Banner deleted successfully")),
                );
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showBannerDialog(BuildContext context, TournamentProvider provider, Map<String, dynamic>? banner) {
    final titleController = TextEditingController(text: banner?['title']);
    final subController = TextEditingController(text: banner?['sub']);
    final urlController = TextEditingController(text: banner?['url']);
    final linkController = TextEditingController(text: banner?['link']);
    String selectedTarget = banner?['target'] ?? 'none';
    String? selectedTournamentId = banner?['tournamentId'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          bool isUploading = false;

          Future<void> pickAndUploadImage() async {
            final picker = ImagePicker();
            final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
            
            if (pickedFile != null) {
              setState(() => isUploading = true);
              try {
                final storageService = StorageService();
                final url = await storageService.uploadImage('banners', File(pickedFile.path));
                
                if (url != null) {
                  setState(() {
                    urlController.text = url;
                    isUploading = false;
                  });
                }
              } catch (e) {
                setState(() => isUploading = false);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
              }
            }
          }

          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text(banner == null ? "Add Banner" : "Edit Banner"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: pickAndUploadImage,
                    child: Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(10),
                        image: urlController.text.isNotEmpty 
                          ? DecorationImage(image: NetworkImage(urlController.text), fit: BoxFit.cover)
                          : null,
                      ),
                      child: isUploading 
                        ? const Center(child: CircularProgressIndicator())
                        : urlController.text.isEmpty 
                          ? const Icon(Icons.add_a_photo, color: Colors.grey)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(controller: titleController, decoration: const InputDecoration(labelText: "Title", border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: subController, decoration: const InputDecoration(labelText: "Subtitle", border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: urlController, decoration: const InputDecoration(labelText: "Image URL", border: OutlineInputBorder())),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: ['none', 'link', 'refer', 'support', 'wallet', 'leaderboard', 'tournament'].contains(selectedTarget) ? selectedTarget : 'none',
                    items: ['none', 'link', 'refer', 'support', 'wallet', 'leaderboard', 'tournament']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase())))
                        .toList(),
                    onChanged: (v) => setState(() => selectedTarget = v!),
                    decoration: const InputDecoration(labelText: "Click Target", border: OutlineInputBorder()),
                  ),
                  if (selectedTarget == 'link') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: linkController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: "External Link",
                        hintText: "https://example.com",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                      ),
                    ),
                  ],
                  if (selectedTarget == 'tournament') ...[
                    const SizedBox(height: 10),
                    StreamBuilder<List<TournamentModel>>(
                      stream: provider.allTournaments(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const CircularProgressIndicator();
                        final tournaments = snapshot.data!;
                        
                        // Safety check for selectedTournamentId
                        if (selectedTournamentId != null && !tournaments.any((t) => t.id == selectedTournamentId)) {
                          selectedTournamentId = null;
                        }

                        return DropdownButtonFormField<String>(
                          value: selectedTournamentId,
                          hint: const Text("Select Tournament"),
                          items: tournaments.map((t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(t.title, overflow: TextOverflow.ellipsis),
                          )).toList(),
                          onChanged: (v) => setState(() => selectedTournamentId = v),
                          decoration: const InputDecoration(labelText: "Tournament", border: OutlineInputBorder()),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () {
                  final data = {
                    'title': titleController.text,
                    'sub': subController.text,
                    'url': urlController.text,
                    'link': selectedTarget == 'link' ? linkController.text.trim() : null,
                    'target': selectedTarget,
                    'tournamentId': selectedTarget == 'tournament' ? selectedTournamentId : null,
                  };
                  if (banner == null) {
                    provider.addBanner(data);
                  } else {
                    provider.updateBanner(banner['id'], data);
                  }
                  Navigator.pop(context);
                },
                child: const Text("Save"),
              ),
            ],
          );
        }
      ),
    );
  }
}
