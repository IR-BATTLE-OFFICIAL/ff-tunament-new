import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/data/models/registration_model.dart';
import 'package:ff_arena/data/models/tournament_model.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:provider/provider.dart';

class ParticipantsScreen extends StatelessWidget {
  final TournamentModel tournament;

  const ParticipantsScreen({super.key, required this.tournament});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TournamentProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PARTICIPANTS'),
      ),
      body: StreamBuilder<List<RegistrationModel>>(
        stream: provider.participants(tournament.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load participants: ${snapshot.error}'));
          }

          final participants = snapshot.data ?? [];
          return Column(
            children: [
              _buildHeader(context, participants.length),
              Expanded(
                child: participants.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: participants.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _ParticipantCard(
                          participant: participants[index],
                          tournament: tournament,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.primary.withValues(alpha: 0.22))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.groups_rounded, color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tournament.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('${tournament.status.toUpperCase()}  •  ${tournament.mode}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$count', style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.bold)),
              const Text('JOINED', style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_search_rounded, size: 64, color: Colors.white24),
          SizedBox(height: 14),
          Text('No participants yet', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('Joined users will appear here', style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }
}

class _ParticipantCard extends StatefulWidget {
  final RegistrationModel participant;
  final TournamentModel tournament;

  const _ParticipantCard({required this.participant, required this.tournament});

  @override
  State<_ParticipantCard> createState() => _ParticipantCardState();
}

class _ParticipantCardState extends State<_ParticipantCard> {
  bool _isPaying = false;

  Future<void> _givePrize() async {
    final amountController = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Give Prize'),
        content: TextField(
          controller: amountController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Prize amount (₹)',
            hintText: 'Enter amount',
            prefixIcon: const Icon(Icons.currency_rupee),
            border: const OutlineInputBorder(),
            errorText: null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(amountController.text.trim());
              if (value == null || value <= 0) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    amountController.dispose();
    if (amount == null || !mounted) return;

    setState(() => _isPaying = true);
    try {
      await Provider.of<TournamentProvider>(context, listen: false).distributeParticipantPrize(
        widget.tournament.id,
        widget.participant.userId,
        amount,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('₹${amount.toStringAsFixed(0)} sent to ${widget.participant.userName}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Prize failed: $error')));
      }
    } finally {
      if (mounted) setState(() => _isPaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final participant = widget.participant;
    final hasPhoto = participant.userProfilePic != null && participant.userProfilePic!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: participant.prizePaid ? Colors.green.withValues(alpha: 0.35) : Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.primary.withValues(alpha: 0.16),
            backgroundImage: hasPhoto ? NetworkImage(participant.userProfilePic!) : null,
            child: hasPhoto ? null : const Icon(Icons.person, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(participant.userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 5),
                Text('UID: ${participant.ffUid}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                if (participant.teamName.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text('Team: ${participant.teamName}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
                const SizedBox(height: 7),
                Row(
                  children: [
                    _Tag(label: participant.slotNumber > 0 ? 'SLOT ${participant.slotNumber}' : 'NO SLOT', color: AppColors.primary),
                    const SizedBox(width: 6),
                    _Tag(label: participant.status.toUpperCase(), color: Colors.greenAccent),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          participant.prizePaid
              ? const _PaidBadge()
              : OutlinedButton.icon(
                  onPressed: _isPaying ? null : _givePrize,
                  icon: _isPaying
                      ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.payments_outlined, size: 17),
                  label: const Text('Prize'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary)),
                ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(5)),
      child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}

class _PaidBadge extends StatelessWidget {
  const _PaidBadge();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 23),
        SizedBox(height: 3),
        Text('PAID', style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
