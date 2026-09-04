import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/presentation/screens/admin/create_tournament_screen.dart';
import 'package:ff_arena/presentation/screens/admin/manage_tournaments_screen.dart';
import 'package:ff_arena/presentation/screens/admin/manage_users_screen.dart';
import 'package:ff_arena/presentation/screens/admin/manage_notifications_screen.dart';
import 'package:ff_arena/presentation/screens/admin/admin_analytics_screen.dart';
import 'package:ff_arena/presentation/screens/admin/manage_banners_screen.dart';
import 'package:ff_arena/presentation/screens/admin/manage_vouchers_screen.dart';
import 'package:ff_arena/presentation/screens/admin/manage_app_config_screen.dart';
import 'package:ff_arena/presentation/screens/admin/admin_support_inbox_screen.dart';
import 'package:ff_arena/presentation/screens/admin/referral_analytics_screen.dart';
import 'package:ff_arena/presentation/screens/admin/manage_reports_screen.dart';
import 'package:ff_arena/presentation/screens/admin/manage_requests_by_status_screen.dart';
import 'package:ff_arena/presentation/screens/admin/manage_game_modes_screen.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:ff_arena/core/services/sms_listener_service.dart';
import 'package:provider/provider.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final _smsListener = SmsListenerService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSmsListener());
  }

  Future<void> _startSmsListener() async {
    final started = await _smsListener.startListening();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(started
            ? 'SMS auto-verification is active for all deposits.'
            : 'Allow SMS permission for automatic deposit credit.'),
        backgroundColor: started ? Colors.green : Colors.orange,
      ),
    );
  }

  @override
  void dispose() {
    _smsListener.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ADMIN CONTROL CENTER"),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Stats Panel Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
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
                  "REAL-TIME STATS",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          _buildQuickStatsPanel(context),

          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final user = auth.userModel;
              if (user == null || !user.isAdmin) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: SwitchListTile(
                    secondary: const Icon(Icons.visibility_off),
                    title: const Text('Hide Admin Identity'),
                    subtitle: const Text('Players will see this account as a normal player.'),
                    value: user.hideAdminIdentity,
                    onChanged: (value) async {
                      await auth.adminUpdateUser(user.uid, {'hideAdminIdentity': value});
                      await auth.refreshUser();
                    },
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "MANAGEMENT MODULES",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                _buildAdminCard(Icons.move_to_inbox, "Manage Requests", "Deposits & Payouts", Colors.orangeAccent, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManageRequestsByStatusScreen(status: 'pending')),
                  );
                }),
                _buildAdminCard(Icons.add_box, "Create Match", "New tournament", AppColors.primary, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CreateTournamentScreen()),
                  );
                }),
                _buildAdminCard(Icons.edit_note, "Manage Matches", "Edit room ID & rules", Colors.cyanAccent, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManageTournamentsScreen()),
                  );
                }),
                _buildAdminCard(Icons.sports_esports, "Manage Game Modes", "Add & active modes", AppColors.primary, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManageGameModesScreen()),
                  );
                }),
                _buildAdminCard(Icons.people, "Manage Users", "Ban, edit balance & tier", Colors.purpleAccent, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManageUsersScreen()),
                  );
                }),
                _buildAdminCard(Icons.report_problem, "Reports & Cheats", "Player complaints", AppColors.neonRed, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManageReportsScreen()),
                  );
                }),
                _buildAdminCard(Icons.image, "Manage Banners", "Home slider images", Colors.pinkAccent, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManageBannersScreen()),
                  );
                }),
                _buildAdminCard(Icons.notifications, "Notifications", "Send push alerts", Colors.lightBlueAccent, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManageNotificationsScreen()),
                  );
                }),
                _buildAdminCard(Icons.analytics, "Analytics", "Revenue & growth", AppColors.accent, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminAnalyticsScreen()),
                  );
                }),
                _buildAdminCard(Icons.confirmation_number, "Manage Vouchers", "Promos & coupons", AppColors.primary, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManageVouchersScreen()),
                  );
                }),
                _buildAdminCard(Icons.settings, "App Settings", "Global app config", Colors.grey, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManageAppConfigScreen()),
                  );
                }),
                _buildAdminCard(Icons.support_agent, "Support Inbox", "User chat tickets", Colors.indigoAccent, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminSupportInboxScreen()),
                  );
                }),
                _buildAdminCard(Icons.group_add, "Referral Analytics", "Referral tracking", Colors.lightGreenAccent, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ReferralAnalyticsScreen()),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsPanel(BuildContext context) {
    return Container(
      height: 74,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildStatCard(
            context,
            "Pending Deposits",
            FirebaseFirestore.instance.collection('deposit_requests').where('status', isEqualTo: 'pending').snapshots(),
            AppColors.neonGreen,
            Icons.add_card,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ManageRequestsByStatusScreen(status: 'pending')),
              );
            },
          ),
          const SizedBox(width: 10),
          _buildStatCard(
            context,
            "Pending Withdraws",
            FirebaseFirestore.instance.collection('withdrawals').where('status', isEqualTo: 'pending').snapshots(),
            Colors.orangeAccent,
            Icons.account_balance_wallet,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ManageRequestsByStatusScreen(status: 'pending')),
              );
            },
          ),
          const SizedBox(width: 10),
          _buildStatCard(
            context,
            "Unread Chats",
            FirebaseFirestore.instance.collection('support_tickets').where('unreadByAdmin', isEqualTo: true).snapshots(),
            AppColors.accent,
            Icons.support_agent,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminSupportInboxScreen()),
              );
            },
          ),
          const SizedBox(width: 10),
          _buildStatCard(
            context,
            "Total Players",
            FirebaseFirestore.instance.collection('users').snapshots(),
            AppColors.primary,
            Icons.people,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ManageUsersScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    Stream<QuerySnapshot> stream,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        String value = "...";
        if (snapshot.hasData) {
          value = snapshot.data!.docs.length.toString();
          if (title == "Total Players") {
            _updatePlayerCount(snapshot.data!.docs.length);
          }
        }

        return Container(
          width: 155,
          decoration: BoxDecoration(
            color: const Color(0xFF10141A),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 8),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                      ),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: color,
                            ),
                          ),
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdminCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF30363D)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Icon(icon, size: 22, color: color),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _updatePlayerCount(int count) {
    FirebaseFirestore.instance.collection('settings').doc('app_config').update({
      'playerCount': count,
    }).catchError((e) {
      debugPrint("Error updating playerCount: $e");
    });
  }
}
