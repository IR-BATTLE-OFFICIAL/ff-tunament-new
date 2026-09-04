import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/core/constants/app_constants.dart';
import 'package:ff_arena/core/utils/url_utils.dart';
import 'package:ff_arena/data/models/user_model.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:ff_arena/presentation/screens/admin/admin_panel_screen.dart';
import 'package:ff_arena/presentation/screens/profile/edit_profile_screen.dart';
import 'package:ff_arena/presentation/screens/wallet/wallet_screen.dart';
import 'package:ff_arena/presentation/screens/profile/refer_earn_screen.dart';
import 'package:ff_arena/presentation/screens/profile/support_chat_screen.dart';
import 'package:ff_arena/presentation/screens/profile/report_player_screen.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:ff_arena/presentation/screens/auth/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Color _getTierColor(UserModel? user) {
    if (user == null) return AppColors.primary;
    if (user.isAdmin && !user.hideAdminIdentity) return AppColors.primary;
    final earnings = user.totalEarnings;
    if (earnings >= 5000) return Colors.purpleAccent;
    if (earnings >= 2000) return Colors.orangeAccent;
    if (earnings >= 1000) return Colors.grey;
    if (earnings >= 500) return Colors.brown;
    return AppColors.primary;
  }

  String _getTierLabel(UserModel? user) {
    if (user == null) return "";
    if (user.isAdmin && !user.hideAdminIdentity) return "ADMIN";
    final earnings = user.totalEarnings;
    if (earnings >= 5000) return "DIAMOND";
    if (earnings >= 2000) return "GOLD";
    if (earnings >= 1000) return "SILVER";
    if (earnings >= 500) return "BRONZE";
    return "";
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final fbUser = fb.FirebaseAuth.instance.currentUser;
    final user = authProvider.userModel ?? (fbUser != null
        ? UserModel(
            uid: fbUser.uid,
            name: fbUser.displayName ?? (fbUser.email != null ? fbUser.email!.split('@').first : 'Gamer'),
            email: fbUser.email ?? '',
            phone: fbUser.phoneNumber,
            balance: 0.0,
            totalWins: 0,
            totalEarnings: 0.0,
          )
        : null);

    final tierColor = _getTierColor(user);
    final tierLabel = _getTierLabel(user);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("MY PROFILE"),
        centerTitle: true,
        actions: [
          if (user != null)
            IconButton(
              icon: const Icon(Icons.logout, color: AppColors.neonRed),
              tooltip: "Logout",
              onPressed: () => _confirmLogout(context, authProvider),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: user == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_circle, size: 64, color: AppColors.primary),
                  const SizedBox(height: 16),
                  const Text("You are not logged in", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    child: const Text("LOGIN NOW", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                children: [
                  // User Profile Header
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.goldGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: tierColor.withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 46,
                                backgroundColor: AppColors.surface,
                                backgroundImage: (user.profilePic != null && user.profilePic!.isNotEmpty)
                                    ? NetworkImage(user.profilePic!)
                                    : null,
                                child: (user.profilePic == null || user.profilePic!.isEmpty)
                                    ? const Icon(Icons.person, size: 46, color: AppColors.primary)
                                    : null,
                              ),
                            ),
                            if (tierLabel.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: tierColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: tierColor.withValues(alpha: 0.6), blurRadius: 6),
                                  ],
                                ),
                                child: Icon(
                                  user.isAdmin && !user.hideAdminIdentity ? Icons.verified : Icons.emoji_events,
                                  size: 16,
                                  color: Colors.black,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          user.name ?? "Gamer",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: tierColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (tierLabel.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            margin: const EdgeInsets.only(top: 4, bottom: 4),
                            decoration: BoxDecoration(
                              color: tierColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: tierColor.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              tierLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: tierColor,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        Text(
                          user.email ?? "",
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3-Column Gaming Stats Card
                  _buildStatRow(user),

                  const SizedBox(height: 24),

                  // Options Section Header
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "ACCOUNT MENU",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Profile Action Cards
                  if (user.isAdmin)
                    _buildAdminOptionCard(context),

                  _buildProfileOptionCard(
                    context,
                    Icons.edit_note,
                    "Edit Profile",
                    "Update your FF UID, Name & Profile",
                    AppColors.accent,
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen())),
                  ),
                  _buildProfileOptionCard(
                    context,
                    Icons.history_toggle_off,
                    "Transaction History",
                    "View wallet deposit & withdrawal logs",
                    AppColors.neonGreen,
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WalletScreen())),
                  ),
                  _buildProfileOptionCard(
                    context,
                    Icons.card_giftcard,
                    "Refer & Earn",
                    "Invite friends and earn rewards",
                    AppColors.primary,
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReferEarnScreen())),
                  ),
                  _buildProfileOptionCard(
                    context,
                    Icons.support_agent,
                    "Support Chat",
                    "Live 24/7 gamer support bot",
                    Colors.purpleAccent,
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SupportChatScreen())),
                  ),
                  _buildProfileOptionCard(
                    context,
                    Icons.report_problem_rounded,
                    "Report Cheater / Player 🚨",
                    "Report suspicious players with proof",
                    Colors.redAccent,
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportPlayerScreen())),
                  ),
                  _buildProfileOptionCard(
                    context,
                    Icons.mail_outline,
                    "Support Email",
                    AppConstants.supportEmail,
                    Colors.orangeAccent,
                    () => UrlUtils.sendEmail(AppConstants.supportEmail),
                  ),
                  _buildProfileOptionCard(
                    context,
                    Icons.play_circle_fill,
                    "YouTube Channel",
                    "Watch live streams & highlights",
                    AppColors.neonRed,
                    () => UrlUtils.launchURL(AppConstants.youtubeChannel),
                  ),
                  _buildProfileOptionCard(
                    context,
                    Icons.info_outline,
                    "About Us",
                    "App version ${AppConstants.appVersion}",
                    Colors.white70,
                    () {
                      showAboutDialog(
                        context: context,
                        applicationName: AppConstants.appName,
                        applicationVersion: AppConstants.appVersion,
                        applicationIcon: Image.asset(
                          AppConstants.logoPath,
                          height: 50,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.sports_esports, color: AppColors.primary, size: 50),
                        ),
                        children: [
                          const Text(AppConstants.appDescription),
                        ],
                      );
                    },
                  ),
                  _buildProfileOptionCard(
                    context,
                    Icons.logout,
                    "Logout Account",
                    "Sign out of your IR BATTLE account",
                    AppColors.neonRed,
                    () => _confirmLogout(context, authProvider),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  void _confirmLogout(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF10141A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text("Confirm Logout", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          "Are you sure you want to log out of your IR BATTLE account?",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              authProvider.signOut();
            },
            child: const Text("LOGOUT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 3-Stats Row Card
  Widget _buildStatRow(UserModel user) {
    final wins = user.totalWins.toString();
    final earnings = user.totalEarnings.toStringAsFixed(2);
    final balance = user.balance.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF10141A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF21262D)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            "TOTAL WINS",
            wins,
            Icons.emoji_events,
            AppColors.primary,
          ),
          Container(width: 1, height: 32, color: const Color(0xFF21262D)),
          _buildStatItem(
            "EARNINGS",
            "₹$earnings",
            Icons.military_tech,
            AppColors.neonGreen,
          ),
          Container(width: 1, height: 32, color: const Color(0xFF21262D)),
          _buildStatItem(
            "BALANCE",
            "₹$balance",
            Icons.account_balance_wallet,
            AppColors.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color),
        ),
      ],
    );
  }

  Widget _buildAdminOptionCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E2409), Color(0xFF141A22)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary, width: 1.5),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 10),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPanelScreen()));
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.admin_panel_settings, color: Colors.black, size: 22),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "ADMIN PANEL",
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.primary, letterSpacing: 0.8),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.stars, size: 14, color: AppColors.primary),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text("Manage tournaments, users, deposits & settings", style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileOptionCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: iconColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
