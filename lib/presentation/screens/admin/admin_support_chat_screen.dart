import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class AdminSupportChatScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const AdminSupportChatScreen({
    super.key, 
    required this.userId, 
    required this.userName
  });

  @override
  State<AdminSupportChatScreen> createState() => _AdminSupportChatScreenState();
}

class _AdminSupportChatScreenState extends State<AdminSupportChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _previousMsgCount = 0;

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final provider = Provider.of<TournamentProvider>(context, listen: false);
    _messageController.clear();
    await provider.sendSupportMessage(widget.userId, text, false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TournamentProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userName),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: Colors.green),
            tooltip: "Close Ticket",
            onPressed: () async {
              await provider.closeSupportTicket(widget.userId);
              if (mounted) Navigator.pop(context);
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: provider.supportMessages(widget.userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final messages = snapshot.data ?? [];
                
                // Safe execution only when message count changes (Prevents Infinite Rebuild Loop!)
                if (messages.length != _previousMsgCount) {
                  _previousMsgCount = messages.length;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      provider.markSupportRead(widget.userId, true);
                      _scrollToBottom();
                    }
                  });
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(15),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final bool isUser = msg['isUser'] ?? false;
                    return _buildChatBubble(msg['text'], isUser);
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: isUser ? AppColors.surface : AppColors.primary,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(15),
                topRight: const Radius.circular(15),
                bottomLeft: Radius.circular(isUser ? 0 : 15),
                bottomRight: Radius.circular(isUser ? 15 : 0),
              ),
            ),
            child: Text(
              text,
              style: TextStyle(color: isUser ? Colors.white : Colors.black),
            ),
          ),
          Text(
            isUser ? "User" : "You",
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(10),
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: "Reply to user...",
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: AppColors.primary),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
