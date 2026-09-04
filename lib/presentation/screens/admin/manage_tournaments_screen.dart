import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/data/models/tournament_model.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:ff_arena/presentation/screens/admin/upload_results_screen.dart';
import 'package:ff_arena/presentation/screens/admin/participants_screen.dart';
import 'package:ff_arena/presentation/screens/admin/create_tournament_screen.dart';

class ManageTournamentsScreen extends StatelessWidget {
  const ManageTournamentsScreen({super.key});

  String _prizeBreakdown(Map<String, dynamic> result) {
    final parts = <String>[];
    final positionPrize = (result['positionPrize'] as num?)?.toDouble() ?? 0;
    final killPrize = (result['killPrize'] as num?)?.toDouble() ?? 0;
    final booyahPrize = (result['booyahPrize'] as num?)?.toDouble() ?? 0;
    if (positionPrize > 0) parts.add('Position ₹${positionPrize.toStringAsFixed(0)}');
    if (killPrize > 0) parts.add('Kill ₹${killPrize.toStringAsFixed(0)}');
    if (booyahPrize > 0) parts.add('Booyah ₹${booyahPrize.toStringAsFixed(0)}');
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final tournamentProvider = Provider.of<TournamentProvider>(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Manage Tournaments"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Upcoming"),
              Tab(text: "Live"),
              Tab(text: "Completed"),
            ],
          ),
        ),
        body: StreamBuilder<List<TournamentModel>>(
          stream: tournamentProvider.allTournaments(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text("Error loading tournaments: ${snapshot.error}", style: const TextStyle(color: Colors.redAccent)),
              ));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("No tournaments found"));
            }

            final allTournaments = snapshot.data!;

            return TabBarView(
              children: [
                _buildTournamentList(context, tournamentProvider, allTournaments.where((t) => t.status.trim().toLowerCase() == 'upcoming').toList()),
                _buildTournamentList(context, tournamentProvider, allTournaments.where((t) => t.status.trim().toLowerCase() == 'live').toList()),
                _buildTournamentList(context, tournamentProvider, allTournaments.where((t) => t.status.trim().toLowerCase() == 'completed').toList()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTournamentList(BuildContext context, TournamentProvider provider, List<TournamentModel> tournaments) {
    if (tournaments.isEmpty) return const Center(child: Text("No tournaments in this status"));

    return ListView.builder(
      itemCount: tournaments.length,
      itemBuilder: (context, index) {
        final tournament = tournaments[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      tournament.imageUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 50),
                    ),
                  ),
                  title: Text(
                    tournament.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        "Status: ${tournament.status.toUpperCase()} | Slots: ${tournament.filledSlots}/${tournament.totalSlots}",
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Mode: ${tournament.mode} | ${tournament.matchType}",
                        style: const TextStyle(fontSize: 12, color: AppColors.primary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('dd MMM, hh:mm a (EEEE)').format(tournament.dateTime),
                        style: const TextStyle(fontSize: 11, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatusButton(context, provider, tournament, 'upcoming', Colors.blue),
                    _buildStatusButton(context, provider, tournament, 'live', Colors.green),
                    _buildStatusButton(context, provider, tournament, 'completed', Colors.red),
                  ],
                ),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (tournament.status == 'live')
                      IconButton(
                        icon: const Icon(Icons.assignment_turned_in, color: Colors.green),
                        tooltip: "Add Results & Prizes",
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => UploadResultsScreen(tournament: tournament)),
                          );
                        },
                      ),
                    if (tournament.status == 'completed')
                      IconButton(
                        icon: const Icon(Icons.emoji_events, color: Colors.amber),
                        tooltip: "View Results & Prizes",
                        onPressed: () => _openCompletedResults(context, provider, tournament),
                      ),
                    if (tournament.status == 'completed')
                      IconButton(
                        icon: const Icon(Icons.restart_alt, color: Colors.cyanAccent),
                        tooltip: "Reset for next tournament",
                        onPressed: () => _resetTournament(context, provider, tournament),
                      ),
                    if (tournament.status == 'upcoming' || tournament.status == 'live')
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.orange),
                        tooltip: "Cancel & Refund",
                        onPressed: () => _cancelTournament(context, provider, tournament),
                      ),
                    IconButton(
                      icon: const Icon(Icons.people, color: Colors.blue),
                      tooltip: "View Participants",
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ParticipantsScreen(tournament: tournament),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.alarm_on, color: Colors.deepPurpleAccent),
                      tooltip: "Send Reminder",
                      onPressed: () => _sendMatchReminder(context, provider, tournament),
                    ),
                    IconButton(
                      icon: const Icon(Icons.vpn_key, color: Colors.amber),
                      tooltip: "Set Match Info",
                      onPressed: () => _showMatchInfoDialog(context, provider, tournament),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: AppColors.primary),
                      tooltip: "Edit Tournament",
                      onPressed: () => _showEditTournamentDialog(context, tournament),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: "Delete Tournament",
                      onPressed: () => _deleteTournament(context, provider, tournament),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusButton(BuildContext context, TournamentProvider provider, TournamentModel tournament, String status, Color color) {
    return ElevatedButton(
      onPressed: tournament.status == status
          ? null
          : () async {
              await provider.updateTournament(tournament.id, {'status': status});
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Status changed to ${status.toUpperCase()}")));
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: tournament.status == status ? color : color.withOpacity(0.3),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      ),
      child: Text(status.toUpperCase(), style: const TextStyle(fontSize: 10)),
    );
  }

  Future<void> _resetTournament(BuildContext context, TournamentProvider provider, TournamentModel tournament) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selectedDate == null || !context.mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 18, minute: 0),
    );
    if (selectedTime == null || !context.mounted) return;

    final nextDateTime = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset Tournament?'),
        content: Text(
          'All current participants and the old result list will be removed from the new match. Player history will stay saved. Reopen this tournament on ${DateFormat('dd MMM yyyy, hh:mm a').format(nextDateTime)}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await provider.resetCompletedTournament(tournament.id, nextDateTime);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tournament and old results reset for the next match')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reset failed: $error')));
      }
    }
  }

  void _sendMatchReminder(BuildContext context, TournamentProvider provider, TournamentModel tournament) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Send Reminder?"),
        content: Text("Send a match reminder to all participants of ${tournament.title}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await provider.sendMatchReminder(tournament.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reminder sent")));
            },
            child: const Text("Send"),
          ),
        ],
      ),
    );
  }

  void _showMatchInfoDialog(BuildContext context, TournamentProvider provider, TournamentModel tournament) {
    final roomIdController = TextEditingController(text: tournament.roomId ?? "");
    final passwordController = TextEditingController(text: tournament.roomPassword ?? "");
    final liveStreamController = TextEditingController(text: tournament.liveStreamUrl ?? "");

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Set Match Info"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(controller: roomIdController, decoration: const InputDecoration(labelText: "Room ID")),
            TextFormField(controller: passwordController, decoration: const InputDecoration(labelText: "Room Password")),
            TextFormField(controller: liveStreamController, decoration: const InputDecoration(labelText: "Live Stream URL (Optional)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await provider.updateMatchInfo(tournament.id, roomIdController.text, passwordController.text, liveStreamUrl: liveStreamController.text.isNotEmpty ? liveStreamController.text : null);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _showEditTournamentDialog(BuildContext context, TournamentModel tournament) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateTournamentScreen(tournament: tournament),
      ),
    );
  }

  void _showTournamentResults(BuildContext context, TournamentProvider provider, TournamentModel tournament) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Results: ${tournament.title}"),
        content: StreamBuilder<List<Map<String, dynamic>>>(
          stream: provider.results(tournament.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
            final results = List<Map<String, dynamic>>.from(snapshot.data ?? []);
            if (results.isEmpty) return const Text("Results have not been added yet.");
            results.sort((a, b) {
              final rA = (a['rank'] as num?)?.toInt() ?? 0;
              final rB = (b['rank'] as num?)?.toInt() ?? 0;
              if (rA == 0 && rB == 0) return 0;
              if (rA == 0) return 1;
              if (rB == 0) return -1;
              return rA.compareTo(rB);
            });
            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final result = results[index];
                  final total = (result['prizeWon'] ?? 0).toDouble();
                  return ListTile(
                    leading: CircleAvatar(child: Text("#${result['rank'] ?? '-'}")),
                    title: Text(result['playerName'] ?? 'Player'),
                    subtitle: Text("${result['kills'] ?? 0} kills"),
                    trailing: Text("₹${total.toStringAsFixed(0)}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  );
                },
              ),
            );
          },
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  Future<void> _openCompletedResults(BuildContext context, TournamentProvider provider, TournamentModel tournament) async {
    final results = await provider.results(tournament.id).first;
    if (!context.mounted) return;
    if (results.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => UploadResultsScreen(tournament: tournament)),
      );
      return;
    }
    _showTournamentResults(context, provider, tournament);
  }

  void _deleteTournament(BuildContext context, TournamentProvider provider, TournamentModel tournament) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Tournament?"),
        content: Text("Are you sure you want to delete ${tournament.title}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await provider.deleteTournament(tournament.id);
              Navigator.pop(context);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  void _cancelTournament(BuildContext context, TournamentProvider provider, TournamentModel tournament) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Tournament?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Cancel ${tournament.title} and refund participants?"),
            TextFormField(controller: reasonController, decoration: const InputDecoration(labelText: "Reason")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              if (reasonController.text.isEmpty) return;
              await provider.cancelTournament(tournament.id, reasonController.text);
              Navigator.pop(context);
            },
            child: const Text("Cancel Tournament"),
          ),
        ],
      ),
    );
  }
}
