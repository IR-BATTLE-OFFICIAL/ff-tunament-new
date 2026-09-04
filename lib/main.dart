import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:ff_arena/core/constants/api_keys.dart';
import 'package:ff_arena/firebase_options.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:ff_arena/presentation/screens/splash_screen.dart';
import 'package:ff_arena/presentation/screens/home/main_screen.dart';
import 'package:ff_arena/presentation/screens/auth/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ff_arena/core/utils/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Supabase
    await Supabase.initialize(
      url: ApiKeys.supabaseUrl,
      anonKey: ApiKeys.supabaseAnonKey,
    );

    // Initialize Firebase with a timeout to prevent infinite loading
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10));
    
    // Initialize Notifications in background to avoid blocking app start
    _initializeNotifications();
    
  } catch (e) {
    debugPrint("Initialization error or timeout: $e");
  }
  
  runApp(const FFArenaApp());
}

Future<void> _initializeNotifications() async {
  try {
    final notificationService = NotificationService();
    await notificationService.initialize().timeout(const Duration(seconds: 5));
    await notificationService.subscribeToTopic('all').timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint("Notification initialization failed: $e");
  }
}

class FFArenaApp extends StatelessWidget {
  const FFArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TournamentProvider()),
      ],
      child: MaterialApp(
        title: 'IR BATTLE',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        // While AuthProvider is initializing or refreshing, show Splash
        if (!auth.isReady) {
          return const SplashScreen(isInitial: true);
        }

        // Once ready, check if we have a user logged in
        if (auth.isAuthenticated) {
          if (auth.userModel != null) {
            return const MainScreenWrapper();
          } else {
            // User is logged in but the user model is not loaded/ready yet
            return const SplashScreen(isInitial: true);
          }
        } else {
          // No user is logged in
          return const LoginScreen();
        }
      },
    );
  }
}

class MainScreenWrapper extends StatefulWidget {
  const MainScreenWrapper({super.key});

  @override
  State<MainScreenWrapper> createState() => _MainScreenWrapperState();
}

class _MainScreenWrapperState extends State<MainScreenWrapper> {
  String _currentVersion = "";

  @override
  void initState() {
    super.initState();
    _loadVersion();
    // Pre-fetch user data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).refreshUser();
    });
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _currentVersion = info.version;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final tournamentProvider = Provider.of<TournamentProvider>(context);

    if (!auth.isReady || _currentVersion.isEmpty) {
      return const SplashScreen(isInitial: true);
    }

    return StreamBuilder<Map<String, dynamic>>(
      stream: tournamentProvider.appConfig(),
      builder: (context, snapshot) {
        final config = snapshot.data ?? {};
        final isMaintenance = config['isMaintenanceMode'] ?? false;
        final maintenanceMsg = config['maintenanceMessage'] ?? 'App is under maintenance. Please check back later!';
        final isAdmin = auth.userModel?.isAdmin ?? false;

        // Check for updates
        final latestVersion = config['latestVersion'] ?? _currentVersion;
        final updateUrl = config['updateUrl'] ?? 'https://arena-battle-tv-official.netlify.app';
        final updateMsg = config['updateMsg'] ?? 'A new version of FF Arena is available. Please update to continue.';
        final updateType = config['updateType'] ?? 'minor'; // 'major' forces update

        // Simple version comparison (e.g., "1.0.1" vs "1.0.2")
        bool hasUpdate = _isVersionLower(_currentVersion, latestVersion);

        if (hasUpdate && !isAdmin) {
          return UpdateScreen(
            version: latestVersion,
            message: updateMsg,
            url: updateUrl,
            isForced: updateType == 'major',
          );
        }

        if (isMaintenance && !isAdmin) {
          return MaintenanceScreen(message: maintenanceMsg);
        }

        return const MainScreen();
      },
    );
  }

  bool _isVersionLower(String current, String latest) {
    try {
      List<int> currentParts = current.split('.').map(int.parse).toList();
      List<int> latestParts = latest.split('.').map(int.parse).toList();

      for (int i = 0; i < latestParts.length; i++) {
        int currentPart = i < currentParts.length ? currentParts[i] : 0;
        if (latestParts[i] > currentPart) return true;
        if (latestParts[i] < currentPart) return false;
      }
    } catch (e) {
      return current != latest;
    }
    return false;
  }
}

class MaintenanceScreen extends StatelessWidget {
  final String message;
  const MaintenanceScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.build_circle, size: 100, color: Colors.orangeAccent),
            const SizedBox(height: 30),
            const Text(
              "UNDER MAINTENANCE",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Colors.orangeAccent),
            const SizedBox(height: 50),
            const Text(
              "We'll be back shortly. Thank you for your patience!",
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class UpdateScreen extends StatelessWidget {
  final String version;
  final String message;
  final String url;
  final bool isForced;

  const UpdateScreen({
    super.key,
    required this.version,
    required this.message,
    required this.url,
    required this.isForced,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.system_update, size: 100, color: AppColors.primary),
            const SizedBox(height: 30),
            Text(
              "UPDATE AVAILABLE (v$version)",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () async {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  "UPDATE NOW",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            if (!isForced) ...[
              const SizedBox(height: 15),
              TextButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const MainScreen()),
                ),
                child: const Text("Maybe Later", style: TextStyle(color: Colors.grey)),
              ),
            ],
            const SizedBox(height: 50),
            const Text(
              "Please update to the latest version to enjoy new features and improved performance.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

