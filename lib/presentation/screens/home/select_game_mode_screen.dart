import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/data/models/game_mode_model.dart';
import 'package:ff_arena/data/models/tournament_model.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:ff_arena/presentation/widgets/tournament_card.dart';
import 'package:provider/provider.dart';

class SelectGameModeScreen extends StatefulWidget {
  const SelectGameModeScreen({super.key});

  @override
  State<SelectGameModeScreen> createState() => _SelectGameModeScreenState();
}

class _SelectGameModeScreenState extends State<SelectGameModeScreen> {
  String _selectedMode = 'All';
  String _selectedType = 'All'; // Solo, Duo, Squad

  final List<String> _types = ['All', 'Solo', 'Duo', 'Squad'];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TournamentProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('SELECT GAME MODE')),
      body: StreamBuilder<List<GameModeModel>>(
        stream: provider.gameModes(onlyActive: true),
        builder: (context, modeSnapshot) {
          final modes = [
            _GameMode('All', Icons.sports_esports, Colors.white, 'All game modes'),
            _GameMode('BR Rank', Icons.map, Colors.greenAccent, 'Battle Royale Rank Mode'),
            _GameMode('CS Rank', Icons.grid_view, AppColors.primary, 'Clash Squad Rank Mode'),
            _GameMode('Lone Wolf', Icons.person, Colors.orangeAccent, 'Solo only mode'),
            _GameMode('Free', Icons.card_giftcard, Colors.lightGreen, 'Free entry tournaments'),
            ...?modeSnapshot.data?.map((mode) => _GameMode(
                  mode.title,
                  Icons.sports_esports,
                  AppColors.primary,
                  '${mode.title} tournaments',
                )),
          ];

          if (!modes.any((mode) => mode.name == _selectedMode)) {
            _selectedMode = 'All';
          }

          return Column(
            children: [
          // Game Mode Cards
          Container(
            height: 115,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: modes.length,
              itemBuilder: (context, i) {
                final mode = modes[i];
                final isSelected = _selectedMode == mode.name;
                return GestureDetector(
                  onTap: () => setState(() => _selectedMode = mode.name),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? mode.color.withOpacity(0.2) : AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? mode.color : Colors.white12,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: mode.color.withOpacity(0.2), blurRadius: 10)]
                          : [],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(mode.icon, color: isSelected ? mode.color : Colors.grey, size: 28),
                        const SizedBox(height: 6),
                        Text(
                          mode.name,
                          style: TextStyle(
                            color: isSelected ? mode.color : Colors.grey,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Match Type Filter
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: _types.map((type) {
                final selected = _selectedType == type;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedType = type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        type,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected ? Colors.black : Colors.grey,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Results
          Expanded(
            child: StreamBuilder<List<TournamentModel>>(
              stream: _getFilteredStream(provider),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sports_esports,
                            size: 70, color: Colors.grey.shade700),
                        const SizedBox(height: 15),
                        const Text('No tournaments found',
                            style: TextStyle(color: Colors.grey, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text(
                          'Try a different mode or type',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                var tournaments = snapshot.data!;

                // Apply match type filter
                if (_selectedType != 'All') {
                  tournaments = tournaments
                      .where((t) => t.matchType == _selectedType)
                      .toList();
                }

                if (tournaments.isEmpty) {
                  return Center(
                    child: Text(
                      'No $_selectedMode + $_selectedType tournaments',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                // Summary bar
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text(
                            '${tournaments.length} tournaments found',
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$_selectedMode • $_selectedType',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: tournaments.length,
                        itemBuilder: (context, index) {
                          return TournamentCard(tournament: tournaments[index]);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
            ),
            ],
          );
        },
      ),
    );
  }

  Stream<List<TournamentModel>> _getFilteredStream(TournamentProvider provider) {
    switch (_selectedMode) {
      case 'BR Rank':
        return provider.tournamentsByMode('BR Rank');
      case 'CS Rank':
        return provider.tournamentsByMode('CS Rank');
      case 'Lone Wolf':
        return provider.tournamentsByMode('Lone Wolf');
      case 'Free':
        return provider.freeTournaments();
      default:
        return _selectedMode == 'All'
            ? provider.getAllUpcomingTournaments()
            : provider.tournamentsByMode(_selectedMode);
    }
  }
}

class _GameMode {
  final String name;
  final IconData icon;
  final Color color;
  final String description;

  const _GameMode(this.name, this.icon, this.color, this.description);
}
