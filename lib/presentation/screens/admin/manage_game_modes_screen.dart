import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/core/utils/storage_service.dart';
import 'package:ff_arena/data/models/game_mode_model.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ManageGameModesScreen extends StatefulWidget {
  const ManageGameModesScreen({super.key});

  @override
  State<ManageGameModesScreen> createState() => _ManageGameModesScreenState();
}

class _ManageGameModesScreenState extends State<ManageGameModesScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TournamentProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Game Modes"),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_fix_high, color: AppColors.primary),
            tooltip: "Seed Default Modes",
            onPressed: () => _confirmSeedDefaults(context, provider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditModeDialog(context, provider),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text("Add Game Mode", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<GameModeModel>>(
        stream: provider.gameModes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final modes = snapshot.data ?? [];

          if (modes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sports_esports_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text("No Game Modes found", style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => provider.seedDefaultGameModes(),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text("Seed 5 Default Modes"),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: modes.length,
            itemBuilder: (context, index) {
              final mode = modes[index];
              return _buildModeCard(context, provider, mode);
            },
          );
        },
      ),
    );
  }

  Widget _buildModeCard(BuildContext context, TournamentProvider provider, GameModeModel mode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mode.isActive ? AppColors.primary.withOpacity(0.3) : Colors.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Banner Preview with Title
          Stack(
            children: [
              Container(
                height: 110,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey.shade900),
                child: mode.bannerUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: mode.bannerUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade900,
                          child: const Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: Colors.grey.shade900,
                        child: const Icon(Icons.sports_esports, color: AppColors.primary, size: 40),
                      ),
              ),
              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.2), Colors.black.withOpacity(0.85)],
                    ),
                  ),
                ),
              ),
              // Position Order Badge
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Position #${mode.order}",
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ),
              // Title Overlay
              Positioned(
                bottom: 12,
                left: 16,
                right: 16,
                child: Text(
                  mode.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 1.2,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),
              ),
            ],
          ),
          // Actions Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Active Switch
                Row(
                  children: [
                    Switch(
                      value: mode.isActive,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        provider.updateGameMode(mode.id, {'isActive': val});
                      },
                    ),
                    Text(
                      mode.isActive ? "Active" : "Hidden",
                      style: TextStyle(
                        color: mode.isActive ? Colors.greenAccent : Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Edit Button
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                  tooltip: "Edit",
                  onPressed: () => _showAddEditModeDialog(context, provider, existingMode: mode),
                ),
                // Delete Button
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                  tooltip: "Delete",
                  onPressed: () => _confirmDelete(context, provider, mode),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, TournamentProvider provider, GameModeModel mode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Game Mode?"),
        content: Text("Are you sure you want to delete '${mode.title}'? Tournaments linked to this mode will keep their name but mode won't appear on Home screen."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.deleteGameMode(mode.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Deleted ${mode.title}"), backgroundColor: Colors.redAccent),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _confirmSeedDefaults(BuildContext context, TournamentProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Seed Default Modes"),
        content: const Text("This will add the 5 default game modes (Battle Royale, Clash Squad, Lone Wolf, Survival, Free Match) if none exist."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.seedDefaultGameModes();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Default modes seeded!"), backgroundColor: Colors.green),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text("Seed Now", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddEditModeDialog(BuildContext context, TournamentProvider provider, {GameModeModel? existingMode}) {
    final titleController = TextEditingController(text: existingMode?.title ?? '');
    final bannerUrlController = TextEditingController(text: existingMode?.bannerUrl ?? '');
    final orderController = TextEditingController(text: existingMode?.order.toString() ?? '1');
    bool isActive = existingMode?.isActive ?? true;
    File? pickedImageFile;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickAndUploadImage() async {
            final picker = ImagePicker();
            final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
            if (picked != null) {
              setDialogState(() {
                pickedImageFile = File(picked.path);
                isUploading = true;
              });
              try {
                final storage = StorageService();
                final url = await storage.uploadImage('game_modes', pickedImageFile!);
                if (url != null) {
                  setDialogState(() {
                    bannerUrlController.text = url;
                    isUploading = false;
                  });
                } else {
                  setDialogState(() => isUploading = false);
                }
              } catch (e) {
                setDialogState(() => isUploading = false);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Upload error: $e")),
                  );
                }
              }
            }
          }

          return AlertDialog(
            title: Text(existingMode != null ? "Edit Game Mode" : "Add New Game Mode"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: "Game Mode Title *",
                      hintText: "e.g. BATTLE ROYALE",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.sports_esports),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Banner Image URL input
                  TextField(
                    controller: bannerUrlController,
                    decoration: const InputDecoration(
                      labelText: "Banner Image URL",
                      hintText: "https://example.com/banner.jpg",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.image),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Image picker button
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: isUploading ? null : pickAndUploadImage,
                          icon: isUploading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.cloud_upload_outlined, size: 18),
                          label: Text(isUploading ? "Uploading..." : "Upload from Gallery"),
                        ),
                      ),
                    ],
                  ),
                  if (bannerUrlController.text.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 70,
                        width: double.infinity,
                        color: Colors.grey.shade900,
                        child: Image.network(
                          bannerUrlController.text,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Text("Preview failed", style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  // Position Order Number
                  TextField(
                    controller: orderController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Position / Order on Home Screen *",
                      hintText: "1, 2, 3, 4...",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.format_list_numbered),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Active Toggle
                  SwitchListTile(
                    title: const Text("Active on Home Screen", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    value: isActive,
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setDialogState(() => isActive = val),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Title is required!")),
                    );
                    return;
                  }
                  final order = int.tryParse(orderController.text.trim()) ?? 1;
                  final bannerUrl = bannerUrlController.text.trim();

                  if (existingMode == null) {
                    // Add new
                    final newMode = GameModeModel(
                      id: '',
                      title: title,
                      bannerUrl: bannerUrl,
                      order: order,
                      isActive: isActive,
                      createdAt: DateTime.now(),
                    );
                    await provider.addGameMode(newMode);
                  } else {
                    // Update existing
                    await provider.updateGameMode(existingMode.id, {
                      'title': title,
                      'bannerUrl': bannerUrl,
                      'order': order,
                      'isActive': isActive,
                    });
                  }

                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(existingMode == null ? "Added Game Mode '$title'!" : "Updated '$title'!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: Text(
                  existingMode == null ? "ADD" : "SAVE",
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
