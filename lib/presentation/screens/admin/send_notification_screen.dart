import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _db = FirebaseFirestore.instance;
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Send Notification")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Notification Title"),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _messageController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: "Message Body"),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendNotification,
                child: _isSending 
                  ? const CircularProgressIndicator(color: Colors.black) 
                  : const Text("SEND TO ALL USERS"),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Note: This will save the notification to the database and trigger a push notification if Cloud Functions are configured.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _sendNotification() async {
    if (_titleController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => _isSending = true);

    try {
      await _db.collection('notifications').add({
        'title': _titleController.text,
        'message': _messageController.text,
        'dateTime': Timestamp.now(),
        'type': 'general',
      });

      if (mounted) {
        await Provider.of<AuthProvider>(context, listen: false).adminIncrementAllUsersUnreadCount();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notification sent successfully!")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      setState(() => _isSending = false);
    }
  }
}
