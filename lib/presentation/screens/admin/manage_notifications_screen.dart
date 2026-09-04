import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ff_arena/presentation/screens/admin/send_notification_screen.dart';

class ManageNotificationsScreen extends StatefulWidget {
  const ManageNotificationsScreen({super.key});

  @override
  State<ManageNotificationsScreen> createState() => _ManageNotificationsScreenState();
}

class _ManageNotificationsScreenState extends State<ManageNotificationsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Notifications")),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SendNotificationScreen()),
          );
        },
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('notifications').orderBy('dateTime', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No notifications found", style: TextStyle(color: Colors.grey)));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final dateTime = (data['dateTime'] as Timestamp).toDate();
              final type = data['type'] ?? 'general';
              final isTargeted = data['userId'] != null;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: type == 'warning' ? Colors.red : AppColors.primary,
                    child: Icon(
                      type == 'warning' ? Icons.warning : Icons.notifications,
                      color: type == 'warning' ? Colors.white : Colors.black,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    data['title'] ?? 'No Title',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['message'] ?? ''),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Text(
                            DateFormat('dd MMM, hh:mm a').format(dateTime),
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          const Spacer(),
                          if (isTargeted)
                            const Text(
                              "Targeted",
                              style: TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                        onPressed: () => _showEditDialog(doc.id, data),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                        onPressed: () => _confirmDelete(doc.id),
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

  void _confirmDelete(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Notification?"),
        content: const Text("Are you sure you want to delete this notification? It will be removed for all users."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await _db.collection('notifications').doc(docId).delete();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notification deleted")));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(String docId, Map<String, dynamic> data) {
    final titleController = TextEditingController(text: data['title']);
    final messageController = TextEditingController(text: data['message']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Notification"),
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
              decoration: const InputDecoration(labelText: "Message"),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty || messageController.text.isEmpty) return;

              await _db.collection('notifications').doc(docId).update({
                'title': titleController.text,
                'message': messageController.text,
              });

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notification updated")));
              }
            },
            child: const Text("Save Changes"),
          ),
        ],
      ),
    );
  }
}
