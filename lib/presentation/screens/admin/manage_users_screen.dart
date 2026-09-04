import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/data/models/user_model.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff_arena/presentation/screens/home/leaderboard_screen.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Users"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search by name...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = "";
                        });
                      },
                    )
                  : null,
                filled: true,
                fillColor: AppColors.secondary,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: authProvider.allUsers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No users found"));
          }

          // Sort users by totalEarnings descending
          final sortedUsers = snapshot.data!;
          sortedUsers.sort((a, b) => (b.totalEarnings).compareTo(a.totalEarnings));

          final filteredUsers = sortedUsers.where((user) {
            return (user.name ?? "").toLowerCase().contains(_searchQuery) ||
                   (user.ffUid ?? "").toLowerCase().contains(_searchQuery);
          }).toList();

          if (filteredUsers.isEmpty) {
            return const Center(child: Text("No matching users found"));
          }

          return ListView.builder(
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              final user = filteredUsers[index];
              // Highlighting top 3 ONLY IF no search is active (showing natural rank)
              bool isTopThree = index < 3 && _searchQuery.isEmpty;
              Color tierColor = _getTierColor(user);
              String tierLabel = _getTierLabel(user);
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                color: user.isAdmin ? Colors.cyan.withOpacity(0.05) : AppColors.surface,
                shape: user.isAdmin ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Colors.cyan, width: 1),
                ) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: tierColor, width: 2),
                              ),
                              child: CircleAvatar(
                                radius: 25,
                                backgroundImage: user.profilePic != null && user.profilePic!.isNotEmpty
                                    ? NetworkImage(user.profilePic!)
                                    : null,
                                child: user.profilePic == null || user.profilePic!.isEmpty
                                    ? const Icon(Icons.person)
                                    : null,
                              ),
                            ),
                            if (user.isAdmin || user.isHighlighted || (isTopThree && !user.isHighlighted))
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: user.isAdmin ? Colors.blue : (user.isHighlighted ? Colors.amber : (index == 0 ? Colors.yellow : (index == 1 ? Colors.grey : Colors.brown))),
                                child: Icon(user.isAdmin ? Icons.verified : (user.isHighlighted ? Icons.star : Icons.emoji_events), size: 10, color: Colors.black),
                              ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(user.name ?? "Gamer", style: TextStyle(fontWeight: FontWeight.bold, color: tierColor))),
                            if (tierLabel.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: tierColor.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                                child: Text(tierLabel, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: tierColor)),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("UID: ${user.ffUid ?? 'N/A'}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            Text("Balance: ${LeaderboardScreen.formatCoin(user.balance)} | Earnings: ${LeaderboardScreen.formatCoin(user.totalEarnings)}", style: TextStyle(color: tierColor.withOpacity(0.8))),
                          ],
                        ),
                        onTap: () => _showUserDetails(context, user),
                      ),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.leaderboard, color: Colors.amber, size: 20),
                            tooltip: "Set Custom Rank",
                            onPressed: () => _showSetRankDialog(context, authProvider, user),
                          ),
                          IconButton(
                            icon: Icon(
                              user.isHighlighted ? Icons.star : Icons.star_border,
                              color: user.isHighlighted ? Colors.yellow : Colors.grey,
                              size: 20,
                            ),
                            tooltip: "Highlight on Leaderboard",
                            onPressed: () => _toggleHighlightStatus(context, authProvider, user),
                          ),
                          IconButton(
                            icon: const Icon(Icons.message, color: Colors.blueAccent, size: 20),
                            tooltip: "Send Personal Notification",
                            onPressed: () => _showPersonalNotificationDialog(context, user),
                          ),
                          IconButton(
                            icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                            tooltip: "Send Warning",
                            onPressed: () => _showWarningDialog(context, user),
                          ),
                          IconButton(
                            icon: Icon(
                              user.isBlocked ? Icons.lock_open : Icons.block,
                              color: user.isBlocked ? Colors.green : Colors.red,
                              size: 20,
                            ),
                            tooltip: user.isBlocked ? "Unblock User" : "Block User",
                            onPressed: () => _toggleBlockStatus(context, authProvider, user),
                          ),
                          IconButton(
                            icon: const Icon(Icons.account_balance_wallet, color: Colors.green, size: 20),
                            tooltip: "Add/Remove Balance",
                            onPressed: () {
                              _showAddBalanceDialog(context, authProvider, user);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.history_toggle_off_rounded, color: Colors.purpleAccent, size: 20),
                            tooltip: "Clear Recent Transactions",
                            onPressed: () => _showClearTransactionsDialog(context, authProvider, user),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showClearTransactionsDialog(BuildContext context, AuthProvider provider, UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Clear History for ${user.name}?"),
        content: Text("Are you sure you want to clear all recent transaction history for ${user.name}? This will remove all transaction records from their wallet."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await provider.clearUserTransactions(user.uid);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Transaction history cleared for ${user.name}!")),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("CLEAR ALL"),
          ),
        ],
      ),
    );
  }

  void _showSetRankDialog(BuildContext context, AuthProvider provider, UserModel user) {
    final controller = TextEditingController(text: user.leaderboardPriority == 0 ? "" : user.leaderboardPriority.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Set Custom Rank for ${user.name}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("1 = Top Rank, 2 = Second, etc.\nEnter 0 to remove manual rank.", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Rank Position", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final priority = int.tryParse(controller.text) ?? 0;
              await provider.adminUpdateUser(user.uid, {
                'leaderboardPriority': priority,
                'isHighlighted': priority != 0, // Automatically highlight if rank is set
              });
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Leaderboard rank updated!")));
                Navigator.pop(context);
              }
            },
            child: const Text("SAVE"),
          ),
        ],
      ),
    );
  }

  Color _getTierColor(UserModel user) {
    if (user.isAdmin) return Colors.cyan;
    if (user.totalEarnings >= 5000) return Colors.purpleAccent; // Diamond
    if (user.totalEarnings >= 2000) return Colors.orange; // Gold
    if (user.totalEarnings >= 1000) return Colors.grey; // Silver
    if (user.totalEarnings >= 500) return Colors.brown; // Bronze
    return Colors.white;
  }

  String _getTierLabel(UserModel user) {
    if (user.isAdmin) return "ADMIN";
    if (user.totalEarnings >= 5000) return "DIAMOND";
    if (user.totalEarnings >= 2000) return "GOLD";
    if (user.totalEarnings >= 1000) return "SILVER";
    if (user.totalEarnings >= 500) return "BRONZE";
    return "";
  }

  void _toggleHighlightStatus(BuildContext context, AuthProvider provider, UserModel user) async {
    await provider.adminUpdateUser(user.uid, {'isHighlighted': !user.isHighlighted});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(user.isHighlighted ? "User removed from highlights" : "User pinned to leaderboard!"),
        backgroundColor: user.isHighlighted ? Colors.grey : AppColors.primary,
      ));
    }
  }

  void _showUserDetails(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 40,
                backgroundImage: user.profilePic != null && user.profilePic!.isNotEmpty
                    ? NetworkImage(user.profilePic!)
                    : null,
                child: user.profilePic == null || user.profilePic!.isEmpty
                    ? const Icon(Icons.person, size: 40)
                    : null,
              ),
              const SizedBox(height: 10),
              Text(user.name ?? "Gamer", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text("Email: ${user.email ?? 'N/A'}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
              
              const TabBar(
                tabs: [
                  Tab(text: "PROFILE"),
                  Tab(text: "TRANSACTIONS"),
                ],
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
              ),
              
              Expanded(
                child: TabBarView(
                  children: [
                    // Profile Tab
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          _detailRow("Free Fire UID", user.ffUid ?? "N/A"),
                          _detailRow("Phone", user.phone ?? "N/A"),
                          _detailRow("Total Wins", user.totalWins.toString()),
                          _detailRow("Total Earnings", "₹${user.totalEarnings}"),
                          _detailRow("Wallet Balance", LeaderboardScreen.formatCoin(user.balance)),
                          _detailRow("Bonus Balance", "₹${user.bonusBalance}"),
                          _detailRow("Referral Code", user.referralCode ?? "N/A"),
                          _detailRow("Device ID", user.deviceId ?? "N/A"),
                          _detailRow("Status", user.isBlocked ? "BLOCKED" : "ACTIVE", 
                            valueColor: user.isBlocked ? Colors.red : Colors.green),
                        ],
                      ),
                    ),
                    
                    // Transactions Tab (from Firestore)
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('transactions')
                          .where('userId', isEqualTo: user.uid)
                          .orderBy('dateTime', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                        final docs = snapshot.data!.docs;
                        if (docs.isEmpty) return const Center(child: Text("No transactions yet"));
                        
                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6.0),
                              child: TextButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showClearTransactionsDialog(context, Provider.of<AuthProvider>(context, listen: false), user);
                                },
                                icon: const Icon(Icons.delete_sweep, color: Colors.redAccent, size: 18),
                                label: const Text("Clear All Transactions", style: TextStyle(color: Colors.redAccent)),
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: docs.length,
                                itemBuilder: (context, i) {
                                  final tx = docs[i].data() as Map<String, dynamic>;
                                  final isCredit = tx['type'] == 'deposit' || tx['type'] == 'prize' || tx['type'] == 'refund';
                                  return ListTile(
                                    title: Text(tx['description'] ?? 'Transaction'),
                                    subtitle: Text((tx['dateTime'] as Timestamp).toDate().toString().substring(0, 16)),
                                    trailing: Text("${isCredit ? '+' : '-'}₹${tx['amount']}", 
                                      style: TextStyle(color: isCredit ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }

  void _toggleBlockStatus(BuildContext context, AuthProvider provider, UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${user.isBlocked ? 'Unblock' : 'Block'} User?"),
        content: Text("Are you sure you want to ${user.isBlocked ? 'unblock' : 'block'} ${user.name}? ${user.isBlocked ? 'They will be able to join matches again.' : 'They will not be able to join or withdraw anymore.'}"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await provider.adminUpdateUser(user.uid, {'isBlocked': !user.isBlocked});
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("User ${user.isBlocked ? 'unblocked' : 'blocked'} successfully!")));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: user.isBlocked ? Colors.green : Colors.red),
            child: Text(user.isBlocked ? "Unblock" : "Block"),
          ),
        ],
      ),
    );
  }

  void _showPersonalNotificationDialog(BuildContext context, UserModel user) {
    final titleController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Notify ${user.name}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Title"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(labelText: "Message", hintText: "Enter notification message..."),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (messageController.text.isEmpty || titleController.text.isEmpty) return;
              
              await FirebaseFirestore.instance.collection('notifications').add({
                'userId': user.uid, // Targeted notification
                'title': titleController.text,
                'message': messageController.text,
                'dateTime': Timestamp.now(),
                'type': 'general',
              });

              // Increment unread count for the targeted user
              if (context.mounted) {
                await Provider.of<AuthProvider>(context, listen: false).adminIncrementUnreadCount(user.uid);
              }

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notification sent successfully!")));
              }
            },
            child: const Text("Send"),
          ),
        ],
      ),
    );
  }

  void _showWarningDialog(BuildContext context, UserModel user) {
    final titleController = TextEditingController(text: "Warning: Fair Play Policy");
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Send Warning to ${user.name}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Warning Title"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(labelText: "Warning Message", hintText: "Enter warning details..."),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (messageController.text.isEmpty) return;
              
              await FirebaseFirestore.instance.collection('notifications').add({
                'userId': user.uid, // Targeted notification
                'title': titleController.text,
                'message': messageController.text,
                'dateTime': Timestamp.now(),
                'type': 'warning',
              });

              // Increment unread count for the targeted user
              if (context.mounted) {
                await Provider.of<AuthProvider>(context, listen: false).adminIncrementUnreadCount(user.uid);
              }

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Warning sent successfully!")));
              }
            },
            child: const Text("Send Warning"),
          ),
        ],
      ),
    );
  }

  void _showAddBalanceDialog(BuildContext context, AuthProvider provider, UserModel user) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Add Balance to ${user.name}"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Amount to add"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text) ?? 0;
              if (amount != 0) {
                await provider.adminUpdateUser(user.uid, {
                  'balance': double.parse((user.balance + amount).toStringAsFixed(2)),
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Balance updated!")));
                  Navigator.pop(context);
                }
              }
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }
}
