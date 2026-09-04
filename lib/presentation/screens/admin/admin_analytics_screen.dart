import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:provider/provider.dart';
import 'package:ff_arena/data/models/user_model.dart';
import 'package:ff_arena/data/models/tournament_model.dart';

class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final tournamentProvider = Provider.of<TournamentProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("App Analytics")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSummaryStats(authProvider, tournamentProvider),
            const SizedBox(height: 24),
            const Text("User Growth & Earnings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildDetailedStats(authProvider, tournamentProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStats(AuthProvider auth, TournamentProvider tournament) {
    return StreamBuilder<List<UserModel>>(
      stream: auth.allUsers,
      builder: (context, userSnapshot) {
        return StreamBuilder<List<TournamentModel>>(
          stream: tournament.allTournaments(),
          builder: (context, tournamentSnapshot) {
            int totalUsers = userSnapshot.data?.length ?? 0;
            int totalTournaments = tournamentSnapshot.data?.length ?? 0;
            double totalPlatformBalance = userSnapshot.data?.fold(0.0, (sum, user) => sum! + user.balance) ?? 0.0;

            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.5,
              children: [
                _buildStatCard("Total Users", totalUsers.toString(), Colors.blue),
                _buildStatCard("Total Matches", totalTournaments.toString(), Colors.orange),
                _buildStatCard("User Wallets", "₹${totalPlatformBalance.toStringAsFixed(0)}", Colors.green),
                _buildStatCard("Revenue (Est)", "₹${(totalTournaments * 50).toStringAsFixed(0)}", Colors.purple),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDetailedStats(AuthProvider auth, TournamentProvider tournament) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _buildDetailRow("Active Tournaments", "Upcoming/Live focus"),
          const Divider(),
          _buildDetailRow("Top Earners", "High competition"),
          const Divider(),
          _buildDetailRow("Withdrawal Load", "Pending requests"),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
