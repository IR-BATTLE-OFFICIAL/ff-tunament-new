import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class FindSquadScreen extends StatefulWidget {
  const FindSquadScreen({super.key});

  @override
  State<FindSquadScreen> createState() => _FindSquadScreenState();
}

class _FindSquadScreenState extends State<FindSquadScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedMode = 'BR Rank';
  String _selectedSlots = '3';
  final TextEditingController _messageController = TextEditingController();

  final List<String> _modes = ['BR Rank', 'CS Rank', 'Lone Wolf'];
  final List<String> _slotOptions = ['1', '2', '3'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _postSquadRequest() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.userModel;
    if (user == null) return;

    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a note about yourself'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      // Remove old request from same user first
      final existing = await FirebaseFirestore.instance
          .collection('squad_requests')
          .where('userId', isEqualTo: user.uid)
          .get();
      for (var doc in existing.docs) {
        await doc.reference.delete();
      }

      await FirebaseFirestore.instance.collection('squad_requests').add({
        'userId': user.uid,
        'userName': user.name ?? 'Unknown',
        'ffUid': user.ffUid ?? 'Not set',
        'profilePic': user.profilePic,
        'mode': _selectedMode,
        'slotsNeeded': int.parse(_selectedSlots),
        'message': _messageController.text.trim(),
        'createdAt': Timestamp.now(),
        'totalWins': user.totalWins,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Squad request posted! Players will contact you.'),
            backgroundColor: Colors.green,
          ),
        );
        _tabController.animateTo(0);
        _messageController.clear();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _leaveRequest() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final uid = auth.userModel?.uid;
    if (uid == null) return;

    final existing = await FirebaseFirestore.instance
        .collection('squad_requests')
        .where('userId', isEqualTo: uid)
        .get();
    for (var doc in existing.docs) {
      await doc.reference.delete();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request removed'), backgroundColor: Colors.grey),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final myUid = auth.userModel?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FIND SQUAD'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'LOOKING FOR SQUAD', icon: Icon(Icons.search)),
            Tab(text: 'POST REQUEST', icon: Icon(Icons.add_circle_outline)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Active Squad Requests
          _buildRequestsList(myUid),

          // Tab 2: Post Your Request
          _buildPostRequest(),
        ],
      ),
    );
  }

  Widget _buildRequestsList(String? myUid) {
    return Column(
      children: [
        // Mode Filter
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: _modes.map((mode) {
              final selected = _selectedMode == mode;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedMode = mode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      mode,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected ? Colors.black : Colors.grey,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('squad_requests')
                .where('mode', isEqualTo: _selectedMode)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group_off, size: 70, color: Colors.grey.shade700),
                      const SizedBox(height: 15),
                      const Text('No squad requests yet', style: TextStyle(color: Colors.grey, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text('Be the first to post a request!',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                );
              }

              final docs = snapshot.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final isMe = data['userId'] == myUid;
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                  final timeAgo = createdAt != null
                      ? _formatTimeAgo(createdAt)
                      : 'Recently';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isMe ? AppColors.primary.withOpacity(0.5) : Colors.white10,
                        width: isMe ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.primary,
                              backgroundImage: data['profilePic'] != null
                                  ? NetworkImage(data['profilePic'])
                                  : null,
                              child: data['profilePic'] == null
                                  ? const Icon(Icons.person, color: Colors.black)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        data['userName'] ?? 'Unknown',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text('YOU',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text('FF UID: ${data['ffUid'] ?? 'N/A'}',
                                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${data['slotsNeeded']} slot${(data['slotsNeeded'] ?? 1) > 1 ? 's' : ''} needed',
                                    style: const TextStyle(
                                        color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('🏆 ${data['totalWins'] ?? 0} wins',
                                    style: const TextStyle(color: Colors.amber, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '"${data['message'] ?? ''}"',
                            style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(timeAgo,
                                style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            if (isMe)
                              GestureDetector(
                                onTap: _leaveRequest,
                                child: const Text('Remove',
                                    style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPostRequest() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Looking for squad? Post here!',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 20),

          // Mode Selection
          const Text('Game Mode', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: _modes.map((mode) {
              final selected = _selectedMode == mode;
              return ChoiceChip(
                label: Text(mode),
                selected: selected,
                onSelected: (_) => setState(() => _selectedMode = mode),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surface,
                labelStyle: TextStyle(
                  color: selected ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Slots Needed
          const Text('Slots Needed', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: _slotOptions.map((slot) {
              final selected = _selectedSlots == slot;
              return ChoiceChip(
                label: Text('$slot player${slot != '1' ? 's' : ''}'),
                selected: selected,
                onSelected: (_) => setState(() => _selectedSlots = slot),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surface,
                labelStyle: TextStyle(
                  color: selected ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Message
          const Text('About Yourself', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 8),
          TextField(
            controller: _messageController,
            maxLines: 3,
            maxLength: 150,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'e.g., Experienced player, looking for Clash Squad team. Always active.',
              counterStyle: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _postSquadRequest,
              icon: const Icon(Icons.group_add, color: Colors.black),
              label: const Text('POST SQUAD REQUEST',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            '• Your FF UID will be visible to others\n• Your request will be auto-removed after 24 hours\n• Be respectful and genuine',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
