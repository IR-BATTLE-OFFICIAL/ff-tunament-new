import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  @override
  void initState() {
    super.initState();
    // Reset unread count when screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).resetUnreadCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userModel = Provider.of<AuthProvider>(context).userModel;
    final userId = userModel?.uid;
    final userCreatedAt = userModel?.createdAt;

    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .orderBy('dateTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No notifications yet", style: TextStyle(color: Colors.grey)));
          }

          // Filter in memory for simplicity (or use complex query)
          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final targetId = data['userId'];
            final notificationTime = (data['dateTime'] as Timestamp).toDate();
            
            // 1. Show if it's general (no userId) or if it's for this specific user
            bool isTargetedToMe = targetId == userId;
            bool isGeneral = targetId == null;
            
            if (!isTargetedToMe && !isGeneral) return false;

            // 2. If it's general, only show if it was sent AFTER the user joined
            if (isGeneral) {
              bool isNewEnough = userCreatedAt == null || 
                                 notificationTime.isAfter(userCreatedAt) || 
                                 notificationTime.isAtSameMomentAs(userCreatedAt);
              if (!isNewEnough) return false;
            }
            
            // If it's targeted to me, show it regardless of createdAt 
            // (since it was obviously sent for me specifically)
            return true;
          }).toList();

          if (docs.isEmpty) {
            return const Center(child: Text("No notifications yet", style: TextStyle(color: Colors.grey)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final dateTime = (data['dateTime'] as Timestamp).toDate();
              final type = data['type'] ?? 'general';

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                color: type == 'warning' ? Colors.red.withOpacity(0.05) : null,
                shape: type == 'warning' 
                  ? RoundedRectangleBorder(side: const BorderSide(color: Colors.red, width: 0.5), borderRadius: BorderRadius.circular(12))
                  : null,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: type == 'warning' ? Colors.red : AppColors.primary,
                    child: Icon(
                      type == 'warning' ? Icons.warning_amber_rounded : Icons.notifications, 
                      color: type == 'warning' ? Colors.white : Colors.black
                    ),
                  ),
                  title: Text(
                    data['title'] ?? 'Announcement', 
                    style: TextStyle(fontWeight: FontWeight.bold, color: type == 'warning' ? Colors.red : null)
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text(data['message'] ?? ''),
                      const SizedBox(height: 10),
                      Text(
                        DateFormat('dd MMM, hh:mm a').format(dateTime),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
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
}
