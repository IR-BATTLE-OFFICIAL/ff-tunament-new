import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/data/models/tournament_model.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:ff_arena/presentation/widgets/tournament_card.dart';
import 'package:provider/provider.dart';

class ModeTournamentsScreen extends StatefulWidget {
  final String gameModeId;
  final String gameModeTitle;

  const ModeTournamentsScreen({
    super.key,
    required this.gameModeId,
    required this.gameModeTitle,
  });

  @override
  State<ModeTournamentsScreen> createState() => _ModeTournamentsScreenState();
}

class _ModeTournamentsScreenState extends State<ModeTournamentsScreen> {
  String _selectedMatchType = 'All'; // All, Solo, Duo, Squad

  final List<String> _matchTypes = ['All', 'Solo', 'Duo', 'Squad'];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TournamentProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.gameModeTitle.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
      ),
      body: Column(
        children: [
          // Match Type filter chips (Solo, Duo, Squad)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.surface,
            child: Row(
              children: [
                const Icon(Icons.filter_list, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _matchTypes.map((type) {
                        final isSelected = _selectedMatchType == type;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(type),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: Colors.white10,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.black : Colors.white70,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedMatchType = type);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tournaments List
          Expanded(
            child: _buildTournamentsStream(
              provider.tournamentsByGameMode(widget.gameModeId, widget.gameModeTitle),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentsStream(Stream<List<TournamentModel>> stream) {
    return StreamBuilder<List<TournamentModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final allMatches = snapshot.data ?? [];
        final modeMatches = allMatches.where((t) {
          // Filter by match type (Solo/Duo/Squad)
          if (_selectedMatchType != 'All') {
            return t.matchType.toLowerCase() == _selectedMatchType.toLowerCase();
          }

          return true;
        }).toList();

        if (modeMatches.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_esports, size: 60, color: Colors.grey.withOpacity(0.4)),
                const SizedBox(height: 12),
                Text(
                  "No ${widget.gameModeTitle} matches right now",
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Stay tuned! New matches will be added soon.",
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: modeMatches.length,
          itemBuilder: (context, index) {
            return TournamentCard(tournament: modeMatches[index]);
          },
        );
      },
    );
  }
}
