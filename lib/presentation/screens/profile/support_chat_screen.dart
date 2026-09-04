import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/core/constants/api_keys.dart';
import 'package:http/http.dart' as http;
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:provider/provider.dart';
import 'package:ff_arena/data/models/user_model.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  bool _isHumanSupport = false;
  int _previousHumanMsgCount = 0;

  String _getSystemPrompt(UserModel user) {
    String prompt = 
      "You are the official AI Support Assistant for the IR BATTLE Free Fire Esports Tournament app. "
      "Your job is to answer every gamer's questions with 100% accuracy, clarity, and friendliness. "
      "\n\nAPP STRUCTURE & UI:\n"
      "- App Name: IR BATTLE\n"
      "- Theme: Esports Dark Gold (#FFB800) and Midnight Background (#0D1117)\n"
      "- Navigation Tabs: Home, Matches, Wallet, Profile\n"
      "- Top Header: Menu Drawer, IR BATTLE logo, Wallet Balance chip (click to add cash), Notification bell\n"
      "- Home Sections: Banners, Game Modes Grid, Live Matches, Mega Tournaments, Free Tournaments, Dynamic Game Mode Match Categories, Pro Victory Tip\n"
      "\n\nDETAILED APP FEATURES & RULES:\n"
      "1. REGISTRATION & LOGIN: Email/Password or Google Login. Device Limit: Max 2 accounts per device for anti-fraud safety.\n"
      "2. ADD CASH / DEPOSIT:\n"
      "   - Minimum Deposit: ₹5\n"
      "   - Payment Methods: GPay, PhonePe, Paytm, BHIM, Merchant UPI QR Scanner\n"
      "   - Auto Credit: Coins credit automatically after payment. 12-Digit UTR (Ref No) manual verification is also available for instant credit.\n"
      "3. WITHDRAWAL:\n"
      "   - Minimum Withdrawal: ₹10\n"
      "   - Processing Time: Within 24 hours\n"
      "   - Method: Upload UPI QR Scanner image. Money sent directly to player's UPI QR.\n"
      "4. TOURNAMENT PARTICIPATION:\n"
      "   - Modes: CS Rank, BR Rank, Lone Wolf, Battle Royale, Survival, Free Match, and Admin-created custom modes.\n"
      "   - Match Types: Solo, Duo, Squad\n"
      "   - Room ID & Password: Given in 'My Matches' -> 'Match Details' exactly 15 minutes before the match start time!\n"
      "   - Joining Rule: Enter correct Free Fire Game UID / Name while joining. Must join room before match start time.\n"
      "5. WALLET & BONUS RULES:\n"
      "   - Wallet contains Main Balance (withdrawable) and Bonus Balance.\n"
      "   - Entry Fee Auto Discount: 10% comes from Bonus Balance and 90% from Main Balance automatically!\n"
      "6. REFER & EARN:\n"
      "   - Share your unique Referral Code from Profile -> Refer & Earn.\n"
      "   - Referee gets bonus upon joining, and referrer receives bonus rewards after referee plays their first match!\n"
      "7. REPORTING CHEATERS & HACKERS:\n"
      "   - If someone hacks or cheats in a match, record screen recording proof and send it to our Instagram or Support Chat for immediate disqualify/ban.\n";

    if (user.isAdmin) {
      prompt += "\n\nADMIN PANEL AUTHORIZED INSTRUCTIONS:\n"
          "Since the current user is an ADMIN, you can assist with Admin Panel operations:\n"
          "- Manage Tournaments: Create, Edit, Delete tournaments, set Room ID & Passwords, upload match result screenshots.\n"
          "- Manage Game Modes: Add new game modes with banners and position order for home screen.\n"
          "- Financial Controls: View deposit & withdrawal requests, set Merchant UPI ID and Merchant QR Scanner image.\n"
          "- User Controls: Block/Unblock users, adjust balances, view device IDs.\n"
          "- App Settings: Maintenance mode toggle, app version config, SMS auto-verification toggle.\n";
    } else {
      prompt += "\n\nSECURITY: Do NOT expose admin panel procedures or administrative credentials to standard players.\n";
    }

    prompt += "\nRESPONSE INSTRUCTIONS:\n"
        "- Respond in the SAME LANGUAGE as the user (Hindi, Hinglish, English, Bengali, etc.).\n"
        "- Use EMOJIS (⚡, 💰, 🏆, 🛡️, 🎮) to make responses engaging and easy to read.\n"
        "- Always give clear, step-by-step instructions.\n";
    
    return prompt;
  }

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    if (user == null) return;

    final tournamentProvider = Provider.of<TournamentProvider>(context, listen: false);
    
    tournamentProvider.aiChatHistory(user.uid).listen((history) {
      if (mounted) {
        setState(() {
          _messages.clear();
          if (history.isEmpty) {
            _messages.add({
              "text": "Hello Gamer! 🎮 I am IR BATTLE AI Assistant. How can I help you today? ⚡",
              "isUser": false,
            });
          } else {
            for (var msg in history) {
              _messages.add({
                "text": msg['text'],
                "isUser": msg['isUser'],
              });
            }
          }
        });
        _scrollToBottom();
      }
    });
  }

  Future<String?> _callPollinationsAI(String userMessage, String systemPrompt) async {
    try {
      final url = Uri.parse("https://text.pollinations.ai/");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "messages": [
            {"role": "system", "content": systemPrompt},
            {"role": "user", "content": userMessage},
          ],
          "model": "openai",
          "jsonMode": false,
        }),
      ).timeout(const Duration(seconds: 7));

      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        return response.body.trim();
      }
    } catch (e) {
      debugPrint("Pollinations AI Error: $e");
    }
    return null;
  }

  Future<String?> _callGeminiAI(String userMessage, String systemPrompt) async {
    try {
      final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${ApiKeys.geminiApiKey}",
      );
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": "$systemPrompt\n\nUser Question: $userMessage\n\nRespond helpfully in the exact same language as the user:"}
              ]
            }
          ]
        }),
      ).timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (text != null && text.toString().trim().isNotEmpty) {
          return text.toString().trim();
        }
      }
    } catch (e) {
      debugPrint("Gemini AI Error: $e");
    }
    return null;
  }

  Future<String?> _callOpenRouterAI(String userMessage, String systemPrompt) async {
    try {
      final url = Uri.parse("https://openrouter.ai/api/v1/chat/completions");
      
      List<Map<String, String>> history = [
        {"role": "system", "content": systemPrompt},
      ];
      
      for (var msg in _messages.take(10)) {
        history.add({
          "role": msg['isUser'] ? "user" : "assistant",
          "content": msg['text'].toString(),
        });
      }

      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer ${ApiKeys.openRouterApiKey}",
          "Content-Type": "application/json",
          "HTTP-Referer": "https://irbattle.com",
          "X-Title": "IR BATTLE",
        },
        body: jsonEncode({
          "model": ApiKeys.openRouterModel,
          "messages": history,
          "temperature": 0.6,
          "max_tokens": 800,
        }),
      ).timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'];
        if (content != null && content.toString().trim().isNotEmpty) {
          return content.toString().trim();
        }
      }
    } catch (e) {
      debugPrint("OpenRouter AI Error: $e");
    }
    return null;
  }

  String _getLocalKnowledgeResponse(String query) {
    final q = query.toLowerCase().trim();

    // Greetings
    if (q == 'hi' || q == 'hello' || q == 'hey' || q == 'hlo' || q == 'namaste' || q.contains('kaise ho') || q == 'halo') {
      return "Hello Gamer! 🎮 Namaste! Mai IR BATTLE ka AI Support Assistant hu ⚡\n\nAap mujhse kuch bhi puch sakte hain:\n- **Match kaise khele?**\n- **Room ID aur Password kab milega?**\n- **Add Cash & Withdrawal Help**\n- **Free Matches & Refer Bonus**\n\nKaise help karu aaj aapki?";
    }

    // How to play / Who to play / Join match
    if (q.contains('play') || q.contains('khele') || q.contains('khel') || q.contains('join') || q.contains('match') || q.contains('start')) {
      return "🎮 **IR BATTLE MEIN MATCH KAISE KHELE:**\n\n"
             "1. **Game Mode Chuno:** Home Screen par `Battle Royale`, `Clash Squad`, etc. card par tap karein.\n"
             "2. **Match Select Karein:** Apne pasand ka tournament chunein aur `JOIN` button dabayein.\n"
             "3. **UID & Name Check Karein:** Apna Free Fire UID aur Name confirm karke Slot choose karein.\n"
             "4. **Room ID & Password:** Match start hone se **15 minute pehle** 'Matches' -> 'Match Details' mein Room ID & Password mil jayega!\n"
             "5. **Free Fire Open Karein:** Free Fire game open karke Custom Room join karein aur Booyah marke prize jeetein! 🏆";
    }

    // Room ID & Pass
    if (q.contains('room') || q.contains('id') || q.contains('pass') || q.contains('password')) {
      return "🔑 **ROOM ID & PASSWORD DETAILS** ⚡\n\n"
             "Room ID aur Password match start hone se genau **15 minute pehle** app mein milta hai!\n"
             "👉 Go to: **Matches / My Matches** -> **Match Details** mein dekhein.";
    }

    // Deposit / Add Cash
    if (q.contains('deposit') || q.contains('add cash') || q.contains('paisa') || q.contains('payment') || q.contains('recharge') || q.contains('money')) {
      return "💰 **ADD CASH / DEPOSIT HELP** ⚡\n\n"
             "1. Go to **Wallet** -> **Add Cash**.\n"
             "2. Amount select karein (Minimum ₹5).\n"
             "3. GPay, PhonePe, Paytm, BHIM ya Merchant QR scanner dwara payment karein.\n"
             "4. Payment screenshot upload karein. Balance instant wallet mein credit ho jayega!";
    }

    // Withdrawal
    if (q.contains('withdraw') || q.contains('nikalna') || q.contains('transfer') || q.contains('bank') || q.contains('upi')) {
      return "🏆 **WITHDRAWAL HELP** ⚡\n\n"
             "1. Go to **Wallet** -> **Withdraw**.\n"
             "2. Withdrawal amount bharein (Minimum ₹10).\n"
             "3. Apne UPI QR Scanner ka photo upload karein.\n"
             "4. Request submit karein, paisa 24 ghante ke andar aapke account mein aa jayega!";
    }

    // Free Matches
    if (q.contains('free')) {
      return "🎁 **FREE TOURNAMENTS** ⚡\n\n"
             "IR BATTLE app mein FREE Tournaments bhi hote hain jisme ₹0 entry fee ke sath aap real cash prizes jeet sakte hain! Home page par FREE badge wale matches join karein.";
    }

    // Refer & Earn
    if (q.contains('refer') || q.contains('code') || q.contains('invite')) {
      return "🎁 **REFER & EARN** ⚡\n\n"
             "Profile -> Refer & Earn par jayein. Apna unique Referral Code dosto ke sath share karein aur har friend ke pehle match khelne par bonus rewards paiye!";
    }

    // Hacker / Cheat
    if (q.contains('hack') || q.contains('cheat') || q.contains('hacker') || q.contains('report')) {
      return "🛡️ **ANTI-CHEAT & REPORTING** ⚡\n\n"
             "Agar kisi match mein koi hacker ya cheater aaye, to screen recording video proof ke sath upar **'Talk to Human'** tap karke admin ko bhej dein. Cheater ko turant ban kar diya jata hai.";
    }

    // Human Support
    if (q.contains('admin') || q.contains('human') || q.contains('call') || q.contains('contact') || q.contains('talk')) {
      return "🎧 **LIVE HUMAN ADMIN SUPPORT** ⚡\n\n"
             "Live Admin se baat karne ke liye upar top-right corner par **'Talk to Human'** button par tap karein! Admin aapko direct reply bhejega.";
    }

    // Contextual Intelligent Default Fallback
    return "⚡ **IR BATTLE AI ASSISTANT** 🎮\n\n"
           "Aapke sawaal '$query' ke liye main ye help kar sakta hu:\n\n"
           "1. 🎮 **Match Kaise Khele:** Game Mode select karke JOIN dabayein aur Room ID 15m pehle lein.\n"
           "2. 💰 **Add Cash / Withdraw:** Wallet section se instant QR payment / withdrawal karein.\n"
           "3. 🎧 **Live Admin:** Upar 'Talk to Human' dabakar direct admin se baat karein!";
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = Provider.of<AuthProvider>(context, listen: false).userModel;
    if (user == null) return;

    final tournamentProvider = Provider.of<TournamentProvider>(context, listen: false);

    if (_isHumanSupport) {
      _messageController.clear();
      await tournamentProvider.sendSupportMessage(user.uid, text, true);
      _scrollToBottom();
      return;
    }

    setState(() {
      _messageController.clear();
      _isLoading = true;
    });

    try {
      await tournamentProvider.saveAIMessage(user.uid, text, true);

      final systemPrompt = _getSystemPrompt(user);
      String? aiResponse;

      // 1. Try Pollinations AI (Instant, Free, Multilingual OpenAI model)
      aiResponse = await _callPollinationsAI(text, systemPrompt);

      // 2. Try Gemini REST API
      if (aiResponse == null || aiResponse.trim().isEmpty) {
        aiResponse = await _callGeminiAI(text, systemPrompt);
      }

      // 3. Try OpenRouter AI
      if (aiResponse == null || aiResponse.trim().isEmpty) {
        aiResponse = await _callOpenRouterAI(text, systemPrompt);
      }

      // 4. Fallback to Multi-lingual Smart Knowledge Base
      if (aiResponse == null || aiResponse.trim().isEmpty) {
        aiResponse = _getLocalKnowledgeResponse(text);
      }

      await tournamentProvider.saveAIMessage(user.uid, aiResponse, false);

    } catch (e) {
      final fallbackText = _getLocalKnowledgeResponse(text);
      tournamentProvider.saveAIMessage(user.uid, fallbackText, false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

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

  void _confirmClearHistory(BuildContext context, String uid, TournamentProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text("Clear AI History?", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text("Are you sure you want to clear all AI chat history?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.clearAIChatHistory(uid);
              setState(() {
                _messages.clear();
                _messages.add({
                  "text": "Hello Gamer! 🎮 I am IR BATTLE AI Assistant. How can I help you today? ⚡",
                  "isUser": false,
                });
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("AI chat history cleared! 🧹"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text("CLEAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;
    final tournamentProvider = Provider.of<TournamentProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isHumanSupport ? "Support Agent" : "AI Support", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(_isHumanSupport ? "Typically replies in 15-30m" : "Online 24/7", style: TextStyle(fontSize: 11, color: _isHumanSupport ? Colors.orangeAccent : AppColors.neonGreen)),
          ],
        ),
        actions: [
          if (!_isHumanSupport && user != null) ...[
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white70),
              tooltip: "Clear AI History",
              onPressed: () => _confirmClearHistory(context, user.uid, tournamentProvider),
            ),
            TextButton.icon(
              onPressed: () async {
                setState(() => _isHumanSupport = true);
                await tournamentProvider.startSupportTicket(user.uid, user.name ?? "Gamer");
              },
              icon: const Icon(Icons.support_agent, color: AppColors.primary, size: 18),
              label: const Text("Talk to Human", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ]
          else
            IconButton(
              onPressed: () => setState(() => _isHumanSupport = false),
              icon: const Icon(Icons.smart_toy, color: AppColors.primary),
              tooltip: "Switch to AI",
            )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isHumanSupport 
              ? _buildHumanChat(tournamentProvider, user?.uid ?? '')
              : _buildAIChat(),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildAIChat() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(15),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return _buildChatBubble(msg['text'].toString(), msg['isUser'] == true, "AI Assistant");
      },
    );
  }

  Widget _buildHumanChat(TournamentProvider provider, String uid) {
    if (uid.isEmpty) {
      return const Center(child: Text("Please log in to chat with support.", style: TextStyle(color: Colors.grey)));
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: provider.supportMessages(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        
        final messages = snapshot.data ?? [];
        if (messages.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 50, color: Colors.grey),
                SizedBox(height: 10),
                Text("Waiting for admin to join...", style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        // Safe callback execution only when message count changes (Prevents Infinite Refresh Loop!)
        if (messages.length != _previousHumanMsgCount) {
          _previousHumanMsgCount = messages.length;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              provider.markSupportRead(uid, false);
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
            return _buildChatBubble(msg['text'].toString(), isUser, isUser ? "You" : "Support Agent");
          },
        );
      },
    );
  }

  Widget _buildFormattedText(String text, bool isUser) {
    final List<InlineSpan> spans = [];
    final RegExp exp = RegExp(r'\*\*(.*?)\*\*');
    int lastMatchEnd = 0;

    for (final Match match in exp.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFFF0F6FC),
            fontSize: 14,
            height: 1.5,
          ),
        ));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          color: isUser ? AppColors.primary : AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
          height: 1.5,
        ),
      ));
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: TextStyle(
          color: isUser ? Colors.white : const Color(0xFFF0F6FC),
          fontSize: 14,
          height: 1.5,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildChatBubble(String text, bool isUser, String senderName) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
            decoration: BoxDecoration(
              color: isUser ? const Color(0xFF2A210A) : const Color(0xFF161C26),
              border: Border.all(
                color: isUser ? AppColors.primary.withValues(alpha: 0.5) : const Color(0xFF30363D),
                width: 1,
              ),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isUser ? 18 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isUser) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.smart_toy_rounded, color: AppColors.primary, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        senderName,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                _buildFormattedText(text, isUser),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () {
                        final cleanText = text.replaceAll('**', '');
                        Clipboard.setData(ClipboardData(text: cleanText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Copied to clipboard! 📋"),
                            duration: Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Row(
                          children: [
                            Icon(Icons.copy_rounded, size: 11, color: isUser ? Colors.white38 : AppColors.textMuted),
                            const SizedBox(width: 3),
                            Text(
                              "Copy",
                              style: TextStyle(fontSize: 10, color: isUser ? Colors.white38 : AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              isUser ? "You" : senderName,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 10, 15, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF10141A),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: const Color(0xFF30363D)),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: "Type your message...",
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 8,
                  )
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
