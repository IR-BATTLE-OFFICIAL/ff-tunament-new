import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/data/datasources/tournament_service.dart';
import 'package:ff_arena/data/models/tournament_slot_model.dart';

class AdminTournamentSlotsWidget extends StatelessWidget {
  final String tournamentId;
  final TournamentService _tournamentService = TournamentService();

  AdminTournamentSlotsWidget({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TournamentSlotModel>>(
      stream: _tournamentService.getTournamentSlots(tournamentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No slots initialized"));
        }

        final slots = snapshot.data!;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            childAspectRatio: 0.8, // Slightly taller to fit name
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: slots.length,
          itemBuilder: (context, index) {
            final slot = slots[index];
            final isLocked = slot.status == 'locked';
            
            return Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isLocked ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isLocked ? Colors.red : Colors.green),
              ),
              child: Column(
                children: [
                  Text("${slot.slotNumber}", style: TextStyle(fontWeight: FontWeight.bold, color: isLocked ? Colors.red : Colors.green)),
                  if (isLocked) ...[
                    const SizedBox(height: 4),
                    Text(slot.userName ?? "Unknown", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                  ]
                ],
              ),
            );
          },
        );
      },
    );
  }
}
