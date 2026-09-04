import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/core/constants/app_constants.dart';
import 'package:ff_arena/core/utils/url_utils.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:ff_arena/presentation/screens/home/home_screen.dart';
import 'package:ff_arena/presentation/screens/tournament/my_matches_screen.dart';
import 'package:ff_arena/presentation/screens/wallet/wallet_screen.dart';
import 'package:ff_arena/presentation/screens/profile/profile_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:ff_arena/presentation/screens/home/leaderboard_screen.dart';
import 'package:ff_arena/presentation/screens/profile/support_chat_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:ff_arena/presentation/screens/home/notification_list_screen.dart';
import 'package:ff_arena/presentation/screens/home/how_to_play_screen.dart';
import 'package:ff_arena/core/utils/notification_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  StreamSubscription? _notificationSubscription;
  DateTime? _appStartTime;

  @override
  void initState() {
    super.initState();
    _appStartTime = DateTime.now();
    _checkUpdate();
    _listenForNewNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _listenForNewNotifications() {
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    if (user == null) return;

    _notificationSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('dateTime', isGreaterThan: Timestamp.fromDate(_appStartTime!))
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          final targetId = data['userId'];
          final title = data['title'] ?? 'ArenaTV 🔔';
          final message = data['message'] ?? '';

          // Show if it's for everyone or specifically for this user
          if (targetId == null || targetId == user.uid) {
            // 1. Show real device status-bar / heads-up notification
            NotificationService().showNotification(title: title, body: message);
            // 2. Also show in-app floating snackbar
            _showForegroundAlert(title, message);
          }
        }
      }
    });
  }

  void _showForegroundAlert(String title, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
            Text(message, style: const TextStyle(fontSize: 12)),
          ],
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
        action: SnackBarAction(
          label: "VIEW",
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationListScreen()));
          },
        ),
      ),
    );
  }

  void _checkUpdate() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('app_config').get();
      if (doc.exists) {
        final config = doc.data()!;
        
        // 1. Check Maintenance Mode
        bool isMaintenance = config['isMaintenanceMode'] ?? false;
        if (isMaintenance && mounted) {
          final user = Provider.of<AuthProvider>(context, listen: false).userModel;
          if (user == null || !user.isAdmin) { // Admins can bypass
            _showMaintenanceDialog(config['maintenanceMessage'] ?? 'App is under maintenance.');
            return; // Don't proceed further
          }
        }

        // 2. Check Version Update
        final latestVersion = config['latestVersion'] ?? '1.0.0';
        final currentVersion = AppConstants.appVersion;

        if (_isNewerVersion(latestVersion, currentVersion)) {
          _showUpdateDialog(
            config['updateType'] ?? 'minor',
            config['updateUrl'] ?? '',
            config['updateMsg'] ?? 'A new version of ${AppConstants.appName} is available!',
          );
        }
      }
    } catch (e) {
      debugPrint("Update/Maintenance check failed: $e");
    }
  }

  void _showMaintenanceDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.engineering, color: Colors.orange),
              SizedBox(width: 10),
              Text("Maintenance"),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => SystemNavigator.pop(),
              child: const Text("Exit App"),
            ),
          ],
        ),
      ),
    );
  }

  bool _isNewerVersion(String latest, String current) {
    List<int> latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return latestParts.length > currentParts.length;
  }

  void _showUpdateDialog(String type, String url, String message) {
    bool isForce = type == 'major';
    showDialog(
      context: context,
      barrierDismissible: !isForce,
      builder: (context) => WillPopScope(
        onWillPop: () async => !isForce,
        child: AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.update, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(isForce ? "Update Required" : "New Update Available"),
            ],
          ),
          content: Text(message),
          actions: [
            if (!isForce)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Later", style: TextStyle(color: Colors.grey)),
              ),
            ElevatedButton(
              onPressed: () {
                if (url.isNotEmpty) {
                  UrlUtils.launchURL(url);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Update link not found")));
                }
              },
              child: const Text("Update Now"),
            ),
          ],
        ),
      ),
    );
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const MyMatchesScreen(),
    const WalletScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).userModel;

    return Scaffold(
      drawer: _buildDrawer(context, user),
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          border: const Border(
            top: BorderSide(color: Color(0xFF30363D), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: AppColors.primary.withValues(alpha: 0.18),
            labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.5,
                );
              }
              return const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: AppColors.primary, size: 24);
              }
              return const IconThemeData(color: AppColors.textMuted, size: 22);
            }),
          ),
          child: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            height: 65,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: "HOME",
              ),
              NavigationDestination(
                icon: FaIcon(FontAwesomeIcons.trophy, size: 18),
                selectedIcon: FaIcon(FontAwesomeIcons.trophy, size: 18),
                label: "MATCHES",
              ),
              NavigationDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet),
                label: "WALLET",
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: "PROFILE",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, user) {
    return Drawer(
      backgroundColor: const Color(0xFF0D1117),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1C222B), Color(0xFF0D1117)],
              ),
              border: const Border(bottom: BorderSide(color: Color(0xFF30363D))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.goldGradient,
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 10),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.surface,
                    backgroundImage: user?.profilePic != null ? NetworkImage(user!.profilePic!) : null,
                    child: user?.profilePic == null ? const Icon(Icons.person, color: AppColors.primary, size: 28) : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? "Gamer",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white, letterSpacing: 0.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user?.email ?? "",
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _drawerItem(Icons.leaderboard, "Leaderboard", () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardScreen()));
          }),
          _drawerItem(Icons.support_agent, "Support Chat", () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SupportChatScreen()));
          }),
          _drawerItem(Icons.email_outlined, "Mail Support", () {
            Navigator.pop(context);
            UrlUtils.sendEmail(AppConstants.supportEmail);
          }),
          _drawerItem(Icons.help_outline, "How to Play", () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => const HowToPlayScreen()));
          }),
          const Divider(color: Colors.white10),
          _drawerItem(FontAwesomeIcons.youtube, "YouTube", () {
            Navigator.pop(context);
            UrlUtils.launchURL(AppConstants.youtubeChannel);
          }),
          _drawerItem(FontAwesomeIcons.instagram, "Instagram", () {
            Navigator.pop(context);
            UrlUtils.launchURL(AppConstants.instagramUrl);
          }),
          _drawerItem(FontAwesomeIcons.whatsapp, "WhatsApp", () {
            Navigator.pop(context);
            UrlUtils.launchURL(AppConstants.whatsappChannel);
          }),
          _drawerItem(FontAwesomeIcons.telegram, "Telegram", () {
            Navigator.pop(context);
            UrlUtils.launchURL(AppConstants.telegramGroup);
          }),
          const Divider(color: Colors.white10),
          _drawerItem(Icons.info_outline, "About Us", () {
            Navigator.pop(context);
            showAboutDialog(
              context: context,
              applicationName: AppConstants.appName,
              applicationVersion: AppConstants.appVersion,
              applicationIcon: Container(
                decoration: const BoxDecoration(shape: BoxShape.circle),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  AppConstants.logoPath,
                  height: 50,
                  width: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.sports_esports, color: AppColors.primary, size: 50),
                ),
              ),
              children: [
                const Text(AppConstants.appDescription),
                const SizedBox(height: 15),
                const Text("TOURNAMENT RULES:", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                const Text(AppConstants.privacyPolicy),
                const SizedBox(height: 10),
                const Text("FAIR PLAY POLICY:", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                const Text(AppConstants.fairPlayRules),
              ],
            );
          }),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text("Version ${AppConstants.appVersion}", style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
          ),
        ],
      ),
    );
  }


  Widget _drawerItem(dynamic icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: icon is IconData
          ? Icon(icon, color: AppColors.primary, size: 22)
          : FaIcon(icon, color: AppColors.primary, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      onTap: onTap,
    );
  }
}
