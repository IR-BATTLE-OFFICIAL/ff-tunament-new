import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:ff_arena/presentation/screens/admin/admin_support_chat_screen.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class AdminSupportInboxScreen extends StatelessWidget {
  const AdminSupportInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TournamentProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Support Inbox")),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: provider.supportTickets(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No support tickets found"));
          }

          final tickets = snapshot.data!;

          return ListView.builder(
            itemCount: tickets.length,
            itemBuilder: (context, index) {
              final ticket = tickets[index];
              final String userId = ticket['userId'];
              final String userName = ticket['userName'] ?? "Unknown";
              final String lastMsg = ticket['lastMessage'] ?? "";
              final bool unread = ticket['unreadByAdmin'] ?? false;
              final String status = ticket['status'] ?? "open";
              final DateTime lastTime = (ticket['lastMessageTime'] as Timestamp).toDate();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: status == 'open' ? AppColors.primary : Colors.grey,
                    child: Text(userName[0].toUpperCase(), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(userName, style: TextStyle(fontWeight: unread ? FontWeight.bold : FontWeight.normal)),
                      Text(
                        DateFormat('hh:mm a').format(lastTime),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    lastMsg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: unread ? Colors.white : Colors.white70),
                  ),
                  trailing: unread 
                    ? const Icon(Icons.circle, color: AppColors.primary, size: 12)
                    : (status == 'closed' ? const Icon(Icons.check_circle, color: Colors.green, size: 16) : null),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AdminSupportChatScreen(
                          userId: userId,
                          userName: userName,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
