import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/data/models/user_model.dart';

class HallOfFameScreen extends StatefulWidget {
  const HallOfFameScreen({super.key});

  @override
  State<HallOfFameScreen> createState() => _HallOfFameScreenState();
}

class _HallOfFameScreenState extends State<HallOfFameScreen> {
  String _filter = 'wins'; // 'wins', 'earnings'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 HALL OF FAME'),
      ),
      body: Column(
        children: [
          // Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1B1506), Color(0xFF2A1F00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                const Text(
                  '🏅 ARENA LEGENDS',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Our greatest champions of all time',
                  style: TextStyle(color: Colors.amber.shade200, fontSize: 13),
                ),
              ],
            ),
          ),

          // Filter Tabs
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _filterTab('Most Wins', 'wins'),
                _filterTab('Most Earnings', 'earnings'),
              ],
            ),
          ),

          // List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('isBlocked', isEqualTo: false)
                  .orderBy(_filter == 'wins' ? 'totalWins' : 'totalEarnings', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No legends yet. Be the first!',
                        style: TextStyle(color: Colors.grey)),
                  );
                }

                final users = snapshot.data!.docs
                    .map((doc) => UserModel.fromFirestore(doc))
                    .where((u) =>
                        _filter == 'wins' ? u.totalWins > 0 : u.totalEarnings > 0)
                    .toList();

                if (users.isEmpty) {
                  return const Center(
                    child: Text('No legends yet!', style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final rank = index + 1;
                    return _buildLegendCard(user, rank);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterTab(String label, String value) {
    final selected = _filter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.black : Colors.grey,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendCard(UserModel user, int rank) {
    Color rankColor;
    String rankEmoji;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700);
      rankEmoji = '🥇';
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0);
      rankEmoji = '🥈';
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32);
      rankEmoji = '🥉';
    } else {
      rankColor = Colors.grey.shade600;
      rankEmoji = '#$rank';
    }

    final value = _filter == 'wins'
        ? '${user.totalWins} Wins'
        : '₹${user.totalEarnings.toStringAsFixed(0)} Earned';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rank <= 3 ? rankColor.withOpacity(0.5) : Colors.white10,
          width: rank <= 3 ? 1.5 : 1,
        ),
        gradient: rank <= 3
            ? LinearGradient(
                colors: [AppColors.surface, rankColor.withOpacity(0.05)],
              )
            : null,
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: rank <= 3
                ? Text(rankEmoji, style: const TextStyle(fontSize: 24))
                : Text(
                    rankEmoji,
                    style: TextStyle(
                      color: rankColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
          const SizedBox(width: 12),

          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: rankColor.withOpacity(0.3),
            backgroundImage: user.profilePic != null ? NetworkImage(user.profilePic!) : null,
            child: user.profilePic == null
                ? Icon(Icons.person, color: rankColor, size: 24)
                : null,
          ),
          const SizedBox(width: 12),

          // Name & Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user.name ?? 'Unknown',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    if (user.isHighlighted) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, color: AppColors.primary, size: 14),
                    ],
                  ],
                ),
                Text(
                  'FF UID: ${user.ffUid ?? 'N/A'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),

          // Score
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: rank <= 3 ? rankColor : AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (_filter == 'wins')
                Text(
                  '₹${user.totalEarnings.toStringAsFixed(0)} earned',
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                )
              else
                Text(
                  '${user.totalWins} wins',
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
