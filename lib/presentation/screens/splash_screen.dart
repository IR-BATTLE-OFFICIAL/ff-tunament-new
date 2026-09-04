import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/core/constants/app_constants.dart';
import 'package:ff_arena/presentation/screens/auth/login_screen.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:ff_arena/presentation/screens/home/main_screen.dart';

class SplashScreen extends StatefulWidget {
  final bool isInitial;
  const SplashScreen({super.key, this.isInitial = true});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Animated Glow Background
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.15),
                    blurRadius: 100,
                    spreadRadius: 50,
                  )
                ],
              ),
            ),
          ),
          
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 2),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      AppConstants.logoPath,
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Lottie.network(
                        'https://assets10.lottiefiles.com/packages/lf20_togt1v.json',
                        height: 220,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  AppConstants.appName,
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    shadows: [Shadow(color: Colors.black, blurRadius: 10, offset: Offset(2, 2))],
                  ),
                ),
                const Text(
                  "UNLEASH THE CHAMPION",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    letterSpacing: 3,
                  ),
                ),
                const SizedBox(height: 50),
                const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
              ],
            ),
          ),
          
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "MADE WITH ❤️ FOR GAMERS",
                style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
