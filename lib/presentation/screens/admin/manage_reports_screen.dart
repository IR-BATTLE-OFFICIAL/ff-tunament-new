import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff_arena/data/datasources/supabase_service.dart';
import 'package:ff_arena/core/utils/url_utils.dart';

class ManageReportsScreen extends StatefulWidget {
  const ManageReportsScreen({super.key});

  @override
  State<ManageReportsScreen> createState() => _ManageReportsScreenState();
}

class _ManageReportsScreenState extends State<ManageReportsScreen> {
  final SupabaseService _supabase = SupabaseService();

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.network(url),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("User Reports & Anti-Cheat")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reports')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final reports = snapshot.data!.docs;

          if (reports.isEmpty) {
            return const Center(child: Text("No player reports found."));
          }

          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index].data() as Map<String, dynamic>;
              final reportId = reports[index].id;
              final reportedPlayerName = report['reportedPlayerName'] ?? report['playerName'] ?? 'N/A';
              final reportedFreeFireId = report['reportedFreeFireId'] ?? report['freeFireId'] ?? report['ffUid'] ?? 'N/A';
              final reportedByName = report['reportedByName'] ?? 'User';
              final reportedBy = report['reportedBy'] ?? '';
              final reportedUserId = report['reportedUserId'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.red.withOpacity(0.3), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "🚨 Reported: $reportedPlayerName",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.redAccent,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "FF UID: $reportedFreeFireId",
                                  style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.block, color: Colors.red),
                                tooltip: "Block/Ban User",
                                onPressed: () {
                                  final targetUid = reportedUserId.isNotEmpty ? reportedUserId : reportedFreeFireId;
                                  _blockUser(targetUid);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                tooltip: "Dismiss Report",
                                onPressed: () => _dismissReport(reportId),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 16),
                      Text("Match: ${report['matchTitle'] ?? report['matchId'] ?? 'N/A'}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text("Reason: ${report['reason'] ?? 'N/A'}", style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                      if (report['description'] != null && (report['description'] as String).isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text("Details: ${report['description']}", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                      const SizedBox(height: 6),
                      Text("Reported By: $reportedByName ${reportedBy.isNotEmpty ? '($reportedBy)' : ''}", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      const SizedBox(height: 10),
                      if (report['proofImageUrl'] != null && (report['proofImageUrl'] as String).isNotEmpty) ...[
                        const Text("Proof Screenshot:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white70)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _showFullImage(context, report['proofImageUrl']),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              report['proofImageUrl'],
                              height: 140,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 100,
                                color: Colors.white10,
                                child: const Center(child: Text("Image failed to load", style: TextStyle(color: Colors.white54))),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  void _blockUser(String userId) async {
    try {
      // Block in Supabase
      await _supabase.updateUserProfile(userId, {'isBlocked': true});
      // Block in Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).update({'isBlocked': true});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("User blocked successfully in both databases!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error blocking user: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _dismissReport(String id) async {
    await FirebaseFirestore.instance.collection('reports').doc(id).delete();
  }
}

class UserDetailsWidget extends StatelessWidget {
  final String userId;
  final String label;

  const UserDetailsWidget({super.key, required this.userId, required this.label});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text("$label: Loading info...", style: const TextStyle(fontSize: 12, color: Colors.grey));
        }
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final name = data['name'] ?? 'Unknown';
          final email = data['email'] ?? 'No Email';
          final ffUid = data['ffUid'] ?? 'No FF UID';
          return Text(
            "$label: $name ($email) | FF UID: $ffUid",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
          );
        }
        return Text("$label: ID: $userId (Not found)", style: const TextStyle(fontSize: 12, color: Colors.grey));
      },
    );
  }
}
