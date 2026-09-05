import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/data/models/user_model.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class ReferralAnalyticsScreen extends StatelessWidget {
  const ReferralAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Referral Analytics")),
      body: StreamBuilder<List<UserModel>>(
        stream: authProvider.allUsers,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error loading data: ${snapshot.error}", style: const TextStyle(color: Colors.redAccent)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No users found", style: TextStyle(color: Colors.grey)));
          }

          final allUsers = snapshot.data!;
          
          // Map to store referral counts and earnings
          // Key: Referral Code / User ID, Value: { count: int, users: List<UserModel> }
          Map<String, Map<String, dynamic>> referrerStats = {};

          // First, identify all referrers (users who have a referral code or UID)
          for (var user in allUsers) {
            final codeKey = (user.referralCode != null && user.referralCode!.isNotEmpty) 
                ? user.referralCode! 
                : user.uid;

            referrerStats[codeKey] = {
              'referrer': user,
              'count': 0,
              'referees': <UserModel>[],
            };
          }

          // Then, count how many users were referred by each code or UID
          for (var user in allUsers) {
            if (user.referredBy != null && user.referredBy!.trim().isNotEmpty) {
              final refKey = user.referredBy!.trim();
              
              // Find the referrer by UID or Referral Code
              final referrer = allUsers.firstWhere(
                (u) => u.uid == refKey || (u.referralCode != null && u.referralCode == refKey), 
                orElse: () => UserModel(uid: 'unknown')
              );
              
              if (referrer.uid != 'unknown') {
                final codeKey = (referrer.referralCode != null && referrer.referralCode!.isNotEmpty) 
                    ? referrer.referralCode! 
                    : referrer.uid;

                if (referrerStats.containsKey(codeKey)) {
                  referrerStats[codeKey]!['count'] = (referrerStats[codeKey]!['count'] as int) + 1;
                  (referrerStats[codeKey]!['referees'] as List<UserModel>).add(user);
                }
              }
            }
          }

          // Convert map to list and sort by count descending
          final sortedStats = referrerStats.values.where((stat) => (stat['count'] as int) > 0).toList();
          sortedStats.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

          if (sortedStats.isEmpty) {
            return const Center(child: Text("No referrals found yet", style: TextStyle(color: Colors.grey)));
          }

          return ListView.builder(
            itemCount: sortedStats.length,
            itemBuilder: (context, index) {
              final stat = sortedStats[index];
              final UserModel referrer = stat['referrer'];
              final int count = stat['count'];
              final List<UserModel> referees = stat['referees'];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundImage: referrer.profilePic != null && referrer.profilePic!.isNotEmpty
                        ? NetworkImage(referrer.profilePic!)
                        : null,
                    child: referrer.profilePic == null || referrer.profilePic!.isEmpty
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(referrer.name ?? "Gamer", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Code: ${referrer.referralCode} | Total: $count refs"),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                    child: Text("#${index + 1}", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                  children: [
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text("Referred Users:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                    ),
                    ...referees.map((ref) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.subdirectory_arrow_right, size: 16),
                      title: Text(ref.name ?? "New User", style: const TextStyle(fontSize: 13)),
                      subtitle: Text("Joined: ${ref.createdAt != null ? DateFormat('dd MMM yyyy').format(ref.createdAt!) : 'N/A'}", style: const TextStyle(fontSize: 11)),
                      trailing: Text("₹${ref.totalWins > 0 ? 'Played' : 'New'}", style: TextStyle(color: ref.totalWins > 0 ? Colors.green : Colors.orange, fontSize: 10)),
                    )).toList(),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
