import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:ff_arena/core/constants/app_constants.dart';
import 'package:ff_arena/core/utils/storage_service.dart';

class ManageAppConfigScreen extends StatefulWidget {
  const ManageAppConfigScreen({super.key});

  @override
  State<ManageAppConfigScreen> createState() => _ManageAppConfigScreenState();
}

class _ManageAppConfigScreenState extends State<ManageAppConfigScreen> {
  File? _imageFile;
  File? _qrFile;
  File? _apkFile;
  bool _isUploading = false;
  bool _isQrUploading = false;
  bool _isApkUploading = false;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickQrImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _qrFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadQrCode(TournamentProvider provider) async {
    if (_qrFile == null) return;
    setState(() => _isQrUploading = true);
    try {
      final storageService = StorageService();
      final url = await storageService.uploadImage('settings', _qrFile!);
      await provider.updateAppConfig({'qrCodeUrl': url});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Merchant QR Scanner updated!"), backgroundColor: Colors.green));
        setState(() => _qrFile = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("QR Upload failed: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isQrUploading = false);
    }
  }

  Future<void> _pickApk() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['apk'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _apkFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _uploadApk(TournamentProvider provider, String arch) async {
    if (_apkFile == null) return;

    setState(() => _isApkUploading = true);
    try {
      final storageService = StorageService();
      final fileName = "ff_arena_${arch}_${DateTime.now().millisecondsSinceEpoch}.apk";
      final url = await storageService.uploadFile('apks', _apkFile!, fileName);
      
      await provider.updateAppConfig({
        'apkUrl_$arch': url,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("APK ($arch) uploaded successfully!"), backgroundColor: Colors.green));
        setState(() => _apkFile = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("APK Upload failed: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isApkUploading = false);
    }
  }

  Future<void> _uploadBanner(TournamentProvider provider) async {
    if (_imageFile == null) return;

    setState(() => _isUploading = true);
    try {
      final storageService = StorageService();
      final url = await storageService.uploadImage('settings', _imageFile!);
      await provider.updateAppConfig({'referBannerUrl': url});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Refer banner updated successfully!"), backgroundColor: Colors.green));
        setState(() => _imageFile = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _updateConfig(TournamentProvider provider, Map<String, dynamic> data) async {
    await provider.updateAppConfig(data);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Settings updated successfully!"), backgroundColor: Colors.green));
    }
  }

  Widget _buildApkUploadSection(TournamentProvider provider, Map config, String arch, String defaultDesc) {
    final descController = TextEditingController(text: config['apkDesc_$arch'] ?? defaultDesc);
    final urlController = TextEditingController(text: config['apkUrl_$arch'] ?? '');
    final currentUrl = config['apkUrl_$arch'];

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Architecture: $arch", style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 10),
          TextField(
            controller: descController,
            decoration: const InputDecoration(labelText: "Description (e.g. For modern phones)", border: OutlineInputBorder()),
            onChanged: (v) => config['apkDesc_$arch'] = v.trim(),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: urlController,
            decoration: const InputDecoration(
              labelText: "Direct APK URL", 
              border: OutlineInputBorder(),
              hintText: "https://site.netlify.app/app.apk",
            ),
            onChanged: (v) => config['apkUrl_$arch'] = v.trim(),
          ),
          const SizedBox(height: 15),
          if (currentUrl != null) 
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text("Live Link: ${currentUrl.length > 30 ? '${currentUrl.substring(0, 30)}...' : currentUrl}", style: const TextStyle(fontSize: 10, color: Colors.blueAccent)),
            ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickApk,
                  icon: const Icon(Icons.file_upload, size: 18),
                  label: Text(_apkFile != null ? "Selected" : "Select File"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: (_apkFile == null || _isApkUploading) ? null : () => _uploadApk(provider, arch),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                  child: _isApkUploading 
                    ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text("UPLOAD", style: TextStyle(color: Colors.black, fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _updateConfig(provider, {
                'apkDesc_$arch': descController.text.trim(),
                'apkUrl_$arch': urlController.text.trim(),
              }),
              child: const Text("SAVE APK CONFIG", style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TournamentProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("App Settings")),
      body: StreamBuilder<Map<String, dynamic>>(
        stream: provider.appConfig(),
        builder: (context, snapshot) {
          final config = snapshot.data ?? {};
          final currentBanner = config['referBannerUrl'];
          
          final welcomeCodeController = TextEditingController(text: config['welcomeVoucherCode'] ?? '');
          final welcomeMessageController = TextEditingController(text: config['welcomeMessage'] ?? '');
          final welcomeNotifTitleController = TextEditingController(text: config['welcomeNotifTitle'] ?? 'Welcome to ${AppConstants.appName}! 🎮');
          final welcomeNotifBodyController = TextEditingController(text: config['welcomeNotifBody'] ?? 'Thanks for joining us! Explore tournaments and start winning.');
          
          final latestVersionController = TextEditingController(text: config['latestVersion'] ?? '1.0.0');
          final updateUrlController = TextEditingController(text: config['updateUrl'] ?? '');
          final updateMsgController = TextEditingController(text: config['updateMsg'] ?? 'A new version is available!');
          String updateType = config['updateType'] ?? 'minor';
          
          bool isMaintenance = config['isMaintenanceMode'] ?? false;
          final maintenanceMsgController = TextEditingController(text: config['maintenanceMessage'] ?? 'App is under maintenance. Please check back later!');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 0. Merchant UPI & QR Code Control Section
                const Text("Merchant UPI & QR Scanner", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 6),
                const Text("Set your UPI ID and upload QR Scanner image for Add Cash screen.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 14),
                TextField(
                  controller: TextEditingController(text: config['upiId'] ?? 'monu.paswan@fam'),
                  decoration: const InputDecoration(labelText: "Merchant UPI ID", border: OutlineInputBorder(), hintText: "e.g. yourname@upi"),
                  onChanged: (v) => config['upiId'] = v.trim(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: TextEditingController(text: config['upiName'] ?? 'IR BATTLE Merchant'),
                  decoration: const InputDecoration(labelText: "Merchant Name", border: OutlineInputBorder()),
                  onChanged: (v) => config['upiName'] = v.trim(),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pickQrImage,
                        icon: const Icon(Icons.qr_code_2, size: 18),
                        label: Text(_qrFile != null ? "QR Selected" : "Select QR Image"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (_qrFile == null || _isQrUploading) ? null : () => _uploadQrCode(provider),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        child: _isQrUploading
                          ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Text("UPLOAD QR", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _updateConfig(provider, {
                      'upiId': config['upiId'],
                      'upiName': config['upiName'],
                    }),
                    child: const Text("SAVE UPI DETAILS"),
                  ),
                ),

                const Divider(height: 40),

                // 1. Maintenance Mode
                const Text("App Maintenance", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                const SizedBox(height: 10),
                Card(
                  color: Colors.red.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text("Maintenance Mode"),
                          subtitle: Text(isMaintenance ? "ON (Users cannot access app)" : "OFF (App is live)"),
                          value: isMaintenance,
                          onChanged: (v) => _updateConfig(provider, {'isMaintenanceMode': v}),
                          activeColor: Colors.red,
                        ),
                        if (isMaintenance) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TextField(
                              controller: maintenanceMsgController,
                              decoration: const InputDecoration(labelText: "Maintenance Message"),
                              maxLines: 2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () => _updateConfig(provider, {'maintenanceMessage': maintenanceMsgController.text.trim()}),
                            child: const Text("SAVE MESSAGE"),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const Divider(height: 40),

                // 2. Force Update
                const Text("Force Update Settings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orangeAccent)),
                const SizedBox(height: 10),
                TextField(
                  controller: latestVersionController,
                  decoration: const InputDecoration(labelText: "Latest Version", border: OutlineInputBorder(), hintText: "1.0.1"),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: updateType,
                  items: const [
                    DropdownMenuItem(value: 'minor', child: Text("Minor (Optional)")),
                    DropdownMenuItem(value: 'major', child: Text("Major (Force Update)")),
                  ],
                  onChanged: (v) => updateType = v!,
                  decoration: const InputDecoration(labelText: "Update Type", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: updateUrlController,
                  decoration: const InputDecoration(labelText: "Update Download Link", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: updateMsgController,
                  decoration: const InputDecoration(labelText: "Update Message", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _updateConfig(provider, {
                      'latestVersion': latestVersionController.text.trim(),
                      'updateType': updateType,
                      'updateUrl': updateUrlController.text.trim(),
                      'updateMsg': updateMsgController.text.trim(),
                    }),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
                    child: const Text("SAVE VERSION SETTINGS"),
                  ),
                ),

                const Divider(height: 40),

                const Text("Multi-Architecture APK Management", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                const SizedBox(height: 10),
                const Text("Upload optimized APKs for different devices and set their descriptions.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 20),
                
                _buildApkUploadSection(provider, config, "v7a", "Old Android Phones"),
                const SizedBox(height: 20),
                _buildApkUploadSection(provider, config, "v8a", "Modern Android Phones (Recommended)"),
                const SizedBox(height: 20),
                _buildApkUploadSection(provider, config, "x64", "Emulators & Tablets"),

                const Divider(height: 60),

                const Text("Default Tournament Rules", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 10),
                const Text("Set global rules that will automatically apply to new tournaments.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 15),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SingleChildScrollView(
                    child: TextField(
                      controller: TextEditingController(text: config['defaultRules'] ?? ''),
                      decoration: const InputDecoration(
                        labelText: "Global Rules", 
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                      maxLines: null,
                      onChanged: (v) => config['defaultRules'] = v.trim(),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _updateConfig(provider, {
                      'defaultRules': config['defaultRules'],
                    }),
                    child: const Text("SAVE GLOBAL RULES"),
                  ),
                ),
                
                const Divider(height: 60),

                const Text("App Version & Updates", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 10),
                const Text("Control app updates and force users to update if needed.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 20),
                TextField(
                  controller: latestVersionController,
                  decoration: const InputDecoration(labelText: "Latest Version", border: OutlineInputBorder(), hintText: "E.g. 1.0.2"),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: updateType,
                  items: const [
                    DropdownMenuItem(value: 'minor', child: Text("Minor (User can skip)")),
                    DropdownMenuItem(value: 'major', child: Text("Major (Force Update)")),
                  ],
                  onChanged: (v) => updateType = v!,
                  decoration: const InputDecoration(labelText: "Update Type", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: updateUrlController,
                  decoration: const InputDecoration(labelText: "Update URL", border: OutlineInputBorder(), hintText: "Link to APK or Play Store"),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: updateMsgController,
                  decoration: const InputDecoration(labelText: "Update Message", border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _updateConfig(provider, {
                      'latestVersion': latestVersionController.text.trim(),
                      'updateType': updateType,
                      'updateUrl': updateUrlController.text.trim(),
                      'updateMsg': updateMsgController.text.trim(),
                    }),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text("SAVE UPDATE SETTINGS"),
                  ),
                ),

                const Divider(height: 60),

                const Text("Welcome Bonus & Notification", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 10),
                const Text("Set the welcome message and notification for new users.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 20),
                TextField(
                  controller: welcomeNotifTitleController,
                  decoration: const InputDecoration(labelText: "Notification Title", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: welcomeNotifBodyController,
                  decoration: const InputDecoration(labelText: "Notification Message", border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: welcomeCodeController,
                  decoration: const InputDecoration(labelText: "Bonus Voucher Code (Optional)", border: OutlineInputBorder()),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: welcomeMessageController,
                  decoration: const InputDecoration(labelText: "Welcome Bonus Message (Optional)", border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _updateConfig(provider, {
                      'welcomeNotifTitle': welcomeNotifTitleController.text.trim(),
                      'welcomeNotifBody': welcomeNotifBodyController.text.trim(),
                      'welcomeVoucherCode': welcomeCodeController.text.trim().toUpperCase(),
                      'welcomeMessage': welcomeMessageController.text.trim(),
                    }),
                    child: const Text("SAVE WELCOME SETTINGS"),
                  ),
                ),
                
                const Divider(height: 60),

                const Text("Refer & Earn Banner", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 10),
                const Text("Upload a new image to change the banner in Refer & Earn screen.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 20),
                
                // Current Banner Preview
                const Text("Current Banner:", style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                    image: DecorationImage(
                      image: currentBanner != null 
                        ? NetworkImage(currentBanner) as ImageProvider
                        : const AssetImage("assets/images/banner.png"),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // New Image Selector
                const Text("Select New Image:", style: TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: _imageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_imageFile!, fit: BoxFit.cover),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, size: 40, color: AppColors.primary),
                              SizedBox(height: 10),
                              Text("Click to Select Image", style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: (_imageFile == null || _isUploading) ? null : () => _uploadBanner(provider),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: _isUploading 
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text("UPDATE BANNER", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),

                const Divider(height: 60),

                // ─── Wallet Time Window (Add Cash & Withdraw) ───────────────
                const Text(
                  "Wallet Service Hours",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.tealAccent),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Set daily open/close time for Add Cash & Withdraw. Leave both blank to keep always open.",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 20),
                _WalletTimeSection(config: config, onSave: (data) => _updateConfig(provider, data)),

                const Divider(height: 60),

                const Text("App Share & Referral Rewards", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                const SizedBox(height: 10),
                const Text("Set the download link and reward amounts for referrals.", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 20),
                
                TextField(
                  controller: TextEditingController(text: config['appShareUrl'] ?? 'https://ffarena.com'),
                  decoration: const InputDecoration(labelText: "App Download Link", border: OutlineInputBorder()),
                  onChanged: (v) => config['appShareUrl'] = v.trim(),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: (config['referralEarnAmount'] ?? 10.0).toString()),
                        decoration: const InputDecoration(labelText: "Referrer Earns (₹)", border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => config['referralEarnAmount'] = double.tryParse(v) ?? 10.0,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: (config['referralSignupBonus'] ?? 5.0).toString()),
                        decoration: const InputDecoration(labelText: "New User Bonus (₹)", border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => config['referralSignupBonus'] = double.tryParse(v) ?? 5.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _updateConfig(provider, {
                      'appShareUrl': config['appShareUrl'],
                      'referralEarnAmount': config['referralEarnAmount'],
                      'referralSignupBonus': config['referralSignupBonus'],
                    }),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    child: const Text("SAVE SHARE SETTINGS"),
                  ),
                ),
                const Divider(height: 60),

                const Text("Website Real Stats & Social Links", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
                const SizedBox(height: 10),
                const Text("These values will be shown on your landing page (website).", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 20),
                
                TextField(
                  controller: TextEditingController(text: (config['totalWinnings'] ?? '10000').toString()),
                  decoration: const InputDecoration(labelText: "Total Winnings Distributed (₹)", border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => config['totalWinnings'] = double.tryParse(v.trim()) ?? 0.0,
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: TextEditingController(text: (config['appRating'] ?? '4.8').toString()),
                  decoration: const InputDecoration(labelText: "App Rating (out of 5.0)", border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => config['appRating'] = v.trim(),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: TextEditingController(text: (config['downloadCount'] ?? '0').toString()),
                  decoration: const InputDecoration(labelText: "Total Downloads (from Website)", border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => config['downloadCount'] = int.tryParse(v) ?? 0,
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: TextEditingController(text: config['youtubeUrl'] ?? 'https://www.youtube.com/@ArenaBattlesTV'),
                  decoration: const InputDecoration(labelText: "YouTube Channel Link", border: OutlineInputBorder()),
                  onChanged: (v) => config['youtubeUrl'] = v.trim(),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: TextEditingController(text: config['whatsappChannelUrl'] ?? ''),
                  decoration: const InputDecoration(labelText: "WhatsApp Channel Link", border: OutlineInputBorder()),
                  onChanged: (v) => config['whatsappChannelUrl'] = v.trim(),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: TextEditingController(text: config['instagramUrl'] ?? ''),
                  decoration: const InputDecoration(labelText: "Instagram Link", border: OutlineInputBorder()),
                  onChanged: (v) => config['instagramUrl'] = v.trim(),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: TextEditingController(text: config['telegramUrl'] ?? ''),
                  decoration: const InputDecoration(labelText: "Telegram Link", border: OutlineInputBorder()),
                  onChanged: (v) => config['telegramUrl'] = v.trim(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _updateConfig(provider, {
                      'totalWinnings': config['totalWinnings'],
                      'appRating': config['appRating'],
                      'downloadCount': config['downloadCount'],
                      'youtubeUrl': config['youtubeUrl'],
                      'whatsappChannelUrl': config['whatsappChannelUrl'],
                      'instagramUrl': config['instagramUrl'],
                      'telegramUrl': config['telegramUrl'],
                    }),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                    child: const Text("SAVE WEBSITE DATA"),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Wallet Time Section Widget ───────────────────────────────────────────────
class _WalletTimeSection extends StatefulWidget {
  final Map<String, dynamic> config;
  final void Function(Map<String, dynamic>) onSave;

  const _WalletTimeSection({required this.config, required this.onSave});

  @override
  State<_WalletTimeSection> createState() => _WalletTimeSectionState();
}

class _WalletTimeSectionState extends State<_WalletTimeSection> {
  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;

  TimeOfDay? _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _displayFmt(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final suffix = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:${t.minute.toString().padLeft(2, '0')} $suffix';
  }

  @override
  void initState() {
    super.initState();
    _openTime = _parseTime(widget.config['walletOpenTime']);
    _closeTime = _parseTime(widget.config['walletCloseTime']);
  }

  Future<void> _pickOpen() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _openTime ?? const TimeOfDay(hour: 10, minute: 0),
      helpText: 'Select Wallet OPEN Time',
    );
    if (picked != null) setState(() => _openTime = picked);
  }

  Future<void> _pickClose() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _closeTime ?? const TimeOfDay(hour: 22, minute: 0),
      helpText: 'Select Wallet CLOSE Time',
    );
    if (picked != null) setState(() => _closeTime = picked);
  }

  void _clearTimes() {
    setState(() {
      _openTime = null;
      _closeTime = null;
    });
    widget.onSave({'walletOpenTime': '', 'walletCloseTime': ''});
  }

  void _save() {
    if (_openTime == null || _closeTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please set both Open and Close time, or tap Clear to keep always open."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    widget.onSave({
      'walletOpenTime': _fmt(_openTime!),
      'walletCloseTime': _fmt(_closeTime!),
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAlwaysOpen = _openTime == null && _closeTime == null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isAlwaysOpen ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isAlwaysOpen ? Colors.green : Colors.orange),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAlwaysOpen ? Icons.lock_open : Icons.access_time,
                  size: 14,
                  color: isAlwaysOpen ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 6),
                Text(
                  isAlwaysOpen
                      ? 'Always Open (No Restriction)'
                      : 'Restricted: ${_displayFmt(_openTime!)} – ${_displayFmt(_closeTime!)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isAlwaysOpen ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Time pickers row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickOpen,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.withOpacity(0.5)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.lock_open, color: Colors.green, size: 22),
                        const SizedBox(height: 6),
                        const Text("OPEN", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          _openTime != null ? _displayFmt(_openTime!) : 'Not Set',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: _openTime != null ? Colors.green : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text("Tap to change", style: TextStyle(fontSize: 9, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  children: const [
                    Icon(Icons.arrow_forward, color: Colors.grey, size: 18),
                    SizedBox(height: 4),
                    Text("to", style: TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _pickClose,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.lock, color: Colors.redAccent, size: 22),
                        const SizedBox(height: 6),
                        const Text("CLOSE", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          _closeTime != null ? _displayFmt(_closeTime!) : 'Not Set',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: _closeTime != null ? Colors.redAccent : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text("Tap to change", style: TextStyle(fontSize: 9, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clearTimes,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text("Clear (Always Open)"),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.grey),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text("SAVE HOURS"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
