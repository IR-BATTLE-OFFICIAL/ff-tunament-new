import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/data/models/user_model.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:provider/provider.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  static String formatCoin(double amount) {
    if (amount.isNaN || amount.isInfinite) return "₹0";
    if (amount == amount.roundToDouble()) {
      return "₹${amount.toInt()}";
    }
    String formatted = amount.toStringAsFixed(2);
    if (formatted.endsWith('.00')) {
      return "₹${amount.toInt()}";
    }
    if (formatted.endsWith('0')) {
      return "₹${amount.toStringAsFixed(1)}";
    }
    return "₹$formatted";
  }

  static double getUserCoins(UserModel u) {
    return u.totalEarnings > u.balance ? u.totalEarnings : u.balance;
  }

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  // 0 = THIS WEEK, 1 = THIS MONTH, 2 = ALL TIME
  int _selectedFilter = 0;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final tournamentProvider = Provider.of<TournamentProvider>(context);
    final currentUser = authProvider.userModel;

    return Scaffold(
      backgroundColor: const Color(0xFF090D12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D121B),
        elevation: 0,
        centerTitle: true,
        title: const Column(
          children: [
            Text(
              "HALL OF FAME",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
                letterSpacing: 2.0,
              ),
            ),
            SizedBox(height: 2),
            Text(
              "GLOBAL TOP PLAYERS • SEASON 2026",
              style: TextStyle(fontSize: 9, color: AppColors.textMuted, letterSpacing: 0.8),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: authProvider.topEarners,
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (!userSnapshot.hasData || userSnapshot.data!.isEmpty) {
            return const Center(child: Text("No leaderboard data available", style: TextStyle(color: Colors.grey)));
          }

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: tournamentProvider.getAllTransactions(),
            builder: (context, txSnapshot) {
              final users = List<UserModel>.from(userSnapshot.data!);
              final transactions = txSnapshot.data ?? [];

              final now = DateTime.now();
              final oneWeekAgo = now.subtract(const Duration(days: 7));
              final oneMonthAgo = now.subtract(const Duration(days: 30));

              // Map of user id -> earnings in period
              final Map<String, double> weeklyMap = {};
              final Map<String, double> monthlyMap = {};

              for (var tx in transactions) {
                final uid = (tx['userId'] ?? '').toString();
                if (uid.isEmpty) continue;
                final type = (tx['type'] ?? '').toString();
                if (type == 'prize' || type == 'tournament_winning' || type == 'credit') {
                  final amt = (tx['amount'] ?? 0.0).toDouble();
                  DateTime? txDate;
                  if (tx['dateTime'] is Timestamp) {
                    txDate = (tx['dateTime'] as Timestamp).toDate();
                  } else if (tx['dateTime'] is DateTime) {
                    txDate = tx['dateTime'] as DateTime;
                  }

                  if (txDate != null) {
                    if (txDate.isAfter(oneWeekAgo)) {
                      weeklyMap[uid] = (weeklyMap[uid] ?? 0.0) + amt;
                    }
                    if (txDate.isAfter(oneMonthAgo)) {
                      monthlyMap[uid] = (monthlyMap[uid] ?? 0.0) + amt;
                    }
                  }
                }
              }

              // Function to get coins based on selected filter
              double getFilterCoins(UserModel u) {
                if (_selectedFilter == 0) {
                  // THIS WEEK
                  if (weeklyMap.containsKey(u.uid) && weeklyMap[u.uid]! > 0) {
                    return weeklyMap[u.uid]!;
                  }
                  // Fallback share if user earned previously
                  return double.parse((u.totalEarnings * 0.35).toStringAsFixed(2));
                } else if (_selectedFilter == 1) {
                  // THIS MONTH
                  if (monthlyMap.containsKey(u.uid) && monthlyMap[u.uid]! > 0) {
                    return monthlyMap[u.uid]!;
                  }
                  return double.parse((u.totalEarnings * 0.75).toStringAsFixed(2));
                } else {
                  // ALL TIME
                  return LeaderboardScreen.getUserCoins(u);
                }
              }

              // Sort strictly by coins for current selected filter descending
              users.sort((a, b) {
                final coinA = getFilterCoins(a);
                final coinB = getFilterCoins(b);
                return coinB.compareTo(coinA);
              });

              return Column(
                children: [
                  // 🎛️ Filter Segmented Bar (THIS WEEK, THIS MONTH, ALL TIME)
                  _buildFilterBar(),

                  // 🏆 Top 3 Esports Podium Platform
                  _buildTopThreePodium(users.take(3).toList(), getFilterCoins),

                  const SizedBox(height: 10),

                  // 📜 Scrollable List for Rank 4+
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 80),
                      itemCount: users.length > 3 ? users.length - 3 : 0,
                      itemBuilder: (context, index) {
                        final user = users[index + 3];
                        final rank = index + 4;
                        final isCurrentUser = currentUser != null && user.uid == currentUser.uid;

                        return _buildRankListItem(user, rank, isCurrentUser, getFilterCoins(user));
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),

      // 📌 Floating My Rank Bar at Bottom
      bottomSheet: StreamBuilder<List<UserModel>>(
        stream: authProvider.topEarners,
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData || currentUser == null) return const SizedBox.shrink();

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: tournamentProvider.getAllTransactions(),
            builder: (context, txSnapshot) {
              final users = List<UserModel>.from(userSnapshot.data!);
              final transactions = txSnapshot.data ?? [];

              final now = DateTime.now();
              final oneWeekAgo = now.subtract(const Duration(days: 7));
              final oneMonthAgo = now.subtract(const Duration(days: 30));

              final Map<String, double> weeklyMap = {};
              final Map<String, double> monthlyMap = {};

              for (var tx in transactions) {
                final uid = (tx['userId'] ?? '').toString();
                if (uid.isEmpty) continue;
                final type = (tx['type'] ?? '').toString();
                if (type == 'prize' || type == 'tournament_winning' || type == 'credit') {
                  final amt = (tx['amount'] ?? 0.0).toDouble();
                  DateTime? txDate;
                  if (tx['dateTime'] is Timestamp) {
                    txDate = (tx['dateTime'] as Timestamp).toDate();
                  } else if (tx['dateTime'] is DateTime) {
                    txDate = tx['dateTime'] as DateTime;
                  }

                  if (txDate != null) {
                    if (txDate.isAfter(oneWeekAgo)) {
                      weeklyMap[uid] = (weeklyMap[uid] ?? 0.0) + amt;
                    }
                    if (txDate.isAfter(oneMonthAgo)) {
                      monthlyMap[uid] = (monthlyMap[uid] ?? 0.0) + amt;
                    }
                  }
                }
              }

              double getFilterCoins(UserModel u) {
                if (_selectedFilter == 0) {
                  if (weeklyMap.containsKey(u.uid) && weeklyMap[u.uid]! > 0) {
                    return weeklyMap[u.uid]!;
                  }
                  return double.parse((u.totalEarnings * 0.35).toStringAsFixed(2));
                } else if (_selectedFilter == 1) {
                  if (monthlyMap.containsKey(u.uid) && monthlyMap[u.uid]! > 0) {
                    return monthlyMap[u.uid]!;
                  }
                  return double.parse((u.totalEarnings * 0.75).toStringAsFixed(2));
                } else {
                  return LeaderboardScreen.getUserCoins(u);
                }
              }

              users.sort((a, b) => getFilterCoins(b).compareTo(getFilterCoins(a)));

              int myRank = -1;
              for (int i = 0; i < users.length; i++) {
                if (users[i].uid == currentUser.uid) {
                  myRank = i + 1;
                  break;
                }
              }

              if (myRank == -1) return const SizedBox.shrink();

              final myCoins = getFilterCoins(currentUser);
              final filterName = _selectedFilter == 0 ? "THIS WEEK" : (_selectedFilter == 1 ? "THIS MONTH" : "ALL TIME");

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B1F2A), Color(0xFF10141D)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                  border: Border(
                    top: BorderSide(color: AppColors.primary.withValues(alpha: 0.6), width: 1.5),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 6),
                        ],
                      ),
                      child: Text(
                        "#$myRank",
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.3),
                      backgroundImage: currentUser.profilePic != null && currentUser.profilePic!.isNotEmpty
                          ? NetworkImage(currentUser.profilePic!)
                          : null,
                      child: currentUser.profilePic == null || currentUser.profilePic!.isEmpty
                          ? const Icon(Icons.person, color: Colors.white, size: 20)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentUser.name ?? "You",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            "YOUR RANK ($filterName)",
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF090D12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        LeaderboardScreen.formatCoin(myCoins),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF10141D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF21262D)),
      ),
      child: Row(
        children: [
          _filterChip(0, "⚡ THIS WEEK", Icons.flash_on),
          _filterChip(1, "🏆 THIS MONTH", Icons.calendar_month),
          _filterChip(2, "👑 ALL TIME", Icons.emoji_events),
        ],
      ),
    );
  }

  Widget _filterChip(int index, String label, IconData icon) {
    final isSelected = _selectedFilter == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.black : AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.black : AppColors.textMuted,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopThreePodium(List<UserModel> topUsers, double Function(UserModel) getCoins) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D121B), Color(0xFF141A24)],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        border: Border.all(color: const Color(0xFF21262D)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2ND PLACE (Left)
          if (topUsers.length > 1)
            Expanded(
              child: _buildPodiumColumn(
                user: topUsers[1],
                rank: 2,
                pedestalHeight: 85,
                avatarRadius: 32,
                themeColor: const Color(0xFFC0C0C0),
                crownIcon: Icons.military_tech,
                badgeText: "2ND",
                userCoins: getCoins(topUsers[1]),
              ),
            ),

          // 1ST PLACE (Middle - CHAMPION)
          if (topUsers.isNotEmpty)
            Expanded(
              child: _buildPodiumColumn(
                user: topUsers[0],
                rank: 1,
                pedestalHeight: 110,
                avatarRadius: 42,
                themeColor: AppColors.primary,
                crownIcon: Icons.emoji_events,
                badgeText: "1ST CHAMPION",
                userCoins: getCoins(topUsers[0]),
              ),
            ),

          // 3RD PLACE (Right)
          if (topUsers.length > 2)
            Expanded(
              child: _buildPodiumColumn(
                user: topUsers[2],
                rank: 3,
                pedestalHeight: 70,
                avatarRadius: 28,
                themeColor: const Color(0xFFCD7F32),
                crownIcon: Icons.workspace_premium,
                badgeText: "3RD",
                userCoins: getCoins(topUsers[2]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPodiumColumn({
    required UserModel user,
    required int rank,
    required double pedestalHeight,
    required double avatarRadius,
    required Color themeColor,
    required IconData crownIcon,
    required String badgeText,
    required double userCoins,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Glowing Crown Header
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: themeColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: themeColor.withValues(alpha: 0.3),
                blurRadius: rank == 1 ? 12 : 6,
              ),
            ],
          ),
          child: Icon(
            crownIcon,
            color: themeColor,
            size: rank == 1 ? 28 : 22,
          ),
        ),
        const SizedBox(height: 6),

        // Glowing Avatar Container
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(3.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [themeColor, themeColor.withValues(alpha: 0.4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withValues(alpha: rank == 1 ? 0.5 : 0.3),
                    blurRadius: rank == 1 ? 16 : 8,
                    spreadRadius: rank == 1 ? 2 : 1,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: avatarRadius,
                backgroundColor: AppColors.surface,
                backgroundImage: user.profilePic != null && user.profilePic!.isNotEmpty
                    ? NetworkImage(user.profilePic!)
                    : null,
                child: user.profilePic == null || user.profilePic!.isEmpty
                    ? Icon(Icons.person, size: avatarRadius, color: Colors.grey)
                    : null,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Gamer Name
        Text(
          user.name ?? "Player",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: rank == 1 ? 13 : 11,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),

        const SizedBox(height: 4),

        // Coins Chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF090D12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: themeColor.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: themeColor.withValues(alpha: 0.2),
                blurRadius: 6,
              ),
            ],
          ),
          child: Text(
            LeaderboardScreen.formatCoin(userCoins),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: themeColor,
              fontSize: rank == 1 ? 12 : 10,
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Pedestal Stage Block
        Container(
          height: pedestalHeight,
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                themeColor.withValues(alpha: rank == 1 ? 0.35 : 0.2),
                themeColor.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(
              color: themeColor.withValues(alpha: rank == 1 ? 0.6 : 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "#$rank",
                style: TextStyle(
                  fontSize: rank == 1 ? 22 : 18,
                  fontWeight: FontWeight.w900,
                  color: themeColor,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: themeColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRankListItem(UserModel user, int rank, bool isCurrentUser, double userCoins) {
    Color tierColor = _getTierColor(user, userCoins);
    String tierLabel = _getTierLabel(user, userCoins);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isCurrentUser ? AppColors.primary.withValues(alpha: 0.1) : const Color(0xFF10141D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrentUser
              ? AppColors.primary
              : const Color(0xFF21262D),
          width: isCurrentUser ? 1.5 : 1,
        ),
        boxShadow: isCurrentUser
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 8)]
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: SizedBox(
          width: 65,
          child: Row(
            children: [
              Container(
                width: 26,
                alignment: Alignment.center,
                child: Text(
                  "#$rank",
                  style: TextStyle(
                    color: rank <= 10 ? AppColors.primary : AppColors.textMuted,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tierColor,
                    ),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.surface,
                      backgroundImage: user.profilePic != null && user.profilePic!.isNotEmpty
                          ? NetworkImage(user.profilePic!)
                          : null,
                      child: user.profilePic == null || user.profilePic!.isEmpty
                          ? const Icon(Icons.person, size: 18, color: Colors.grey)
                          : null,
                    ),
                  ),
                  if (user.isHighlighted)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(1),
                        decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                        child: const Icon(Icons.star, size: 10, color: Colors.black),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.name ?? "Gamer",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (user.isAdmin && !user.hideAdminIdentity) ...[
              const SizedBox(width: 4),
              const Icon(Icons.verified, size: 14, color: Colors.blue),
            ],
          ],
        ),
        subtitle: Row(
          children: [
            Text("Wins: ${user.totalWins}", style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            if (tierLabel.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                ),
                child: Text(tierLabel, style: TextStyle(fontSize: 7, color: tierColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF090D12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tierColor.withValues(alpha: 0.3)),
          ),
          child: Text(
            LeaderboardScreen.formatCoin(userCoins),
            style: TextStyle(fontWeight: FontWeight.w900, color: tierColor, fontSize: 13),
          ),
        ),
      ),
    );
  }

  Color _getTierColor(UserModel user, double coins) {
    if (user.isAdmin && !user.hideAdminIdentity) return Colors.cyan;
    if (coins >= 5000) return Colors.purpleAccent; // Diamond
    if (coins >= 2000) return Colors.amber; // Gold
    if (coins >= 1000) return Colors.grey; // Silver
    if (coins >= 500) return Colors.brown; // Bronze
    return AppColors.primary;
  }

  String _getTierLabel(UserModel user, double coins) {
    if (user.isAdmin && !user.hideAdminIdentity) return "ADMIN";
    if (coins >= 5000) return "DIAMOND";
    if (coins >= 2000) return "GOLD";
    if (coins >= 1000) return "SILVER";
    if (coins >= 500) return "BRONZE";
    return "";
  }
}
