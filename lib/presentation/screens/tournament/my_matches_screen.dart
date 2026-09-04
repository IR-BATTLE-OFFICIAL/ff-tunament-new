import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/data/models/registration_model.dart';
import 'package:ff_arena/data/models/tournament_model.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:provider/provider.dart';
import 'package:ff_arena/presentation/screens/tournament/tournament_details_screen.dart';
import 'package:intl/intl.dart';

class MyMatchesScreen extends StatelessWidget {
  const MyMatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).userModel;
    final tournamentProvider = Provider.of<TournamentProvider>(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("My Matches"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Upcoming"),
              Tab(text: "Completed"),
            ],
            indicatorColor: AppColors.primary,
          ),
        ),
        body: user == null
            ? const Center(child: Text("Please Login"))
            : StreamBuilder<List<RegistrationModel>>(
                stream: tournamentProvider.myMatches(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }
                  final allMatches = snapshot.data ?? [];
                  
                  return TabBarView(
                    children: [
                      _buildMatchList(context, allMatches, tournamentProvider, isCompleted: false),
                      _buildMatchList(context, allMatches, tournamentProvider, isCompleted: true),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildMatchList(BuildContext context, List<RegistrationModel> registrations, TournamentProvider provider, {required bool isCompleted}) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getTournamentDetails(registrations, provider),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final list = snapshot.data!.where((item) {
          final status = (item['tournament'] as TournamentModel).status;
          final registration = item['registration'] as RegistrationModel;
          return isCompleted
              ? status == 'completed' || registration.isCompletedHistory
              : status != 'completed' && !registration.isCompletedHistory;
        }).toList();

        if (list.isEmpty) {
          return Center(child: Text("No ${isCompleted ? 'completed' : 'upcoming'} matches", style: const TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          itemCount: list.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final item = list[index];
            final TournamentModel t = item['tournament'];
            final RegistrationModel r = item['registration'];
            
            return Card(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.only(bottom: 15),
              child: InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TournamentDetailsScreen(tournament: t))),
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  children: [
                    ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(t.imageUrl, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.sports_esports)),
                      ),
                      title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${DateFormat('dd MMM, hh:mm a').format(t.dateTime)} | ${t.mode}"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _badge(
                            isCompleted ? 'COMPLETED' : t.status.toUpperCase(),
                            isCompleted ? Colors.greenAccent : (t.status == 'live' ? Colors.red : AppColors.primary),
                          ),
                          if (t.status == 'upcoming' || t.status == 'live')
                            Text(t.roomId != null ? "Room ID Ready!" : "Room ID soon", style: TextStyle(color: t.roomId != null ? Colors.green : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Future<List<Map<String, dynamic>>> _getTournamentDetails(List<RegistrationModel> regs, TournamentProvider provider) async {
    List<Map<String, dynamic>> results = [];
    for (var reg in regs) {
      final t = await provider.getTournamentById(reg.tournamentId);
      if (t != null) {
        results.add({'registration': reg, 'tournament': t});
      }
    }
    return results;
  }
}
