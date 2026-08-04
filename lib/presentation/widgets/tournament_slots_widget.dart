import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/data/datasources/tournament_service.dart';
import 'package:ff_arena/data/models/tournament_slot_model.dart';

class TournamentSlotsWidget extends StatefulWidget {
  final String tournamentId;
  final int totalSlots;
  final Function(TournamentSlotModel?) onSlotSelected;

  const TournamentSlotsWidget({
    super.key,
    required this.tournamentId,
    this.totalSlots = 48,
    required this.onSlotSelected,
  });

  @override
  State<TournamentSlotsWidget> createState() => _TournamentSlotsWidgetState();
}

class _TournamentSlotsWidgetState extends State<TournamentSlotsWidget> {
  TournamentSlotModel? _selectedSlot;
  final TournamentService _tournamentService = TournamentService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TournamentSlotModel>>(
      stream: _tournamentService.getTournamentSlots(
        widget.tournamentId,
        totalSlots: widget.totalSlots,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final List<TournamentSlotModel> slots =
            (snapshot.hasData && snapshot.data!.isNotEmpty)
                ? snapshot.data!
                : List.generate(
                    widget.totalSlots > 0 ? widget.totalSlots : 48,
                    (index) => TournamentSlotModel(
                      id: 'temp_${index + 1}',
                      tournamentId: widget.tournamentId,
                      slotNumber: index + 1,
                      status: 'available',
                    ),
                  );

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.totalSlots > 24 ? 6 : 5,
            childAspectRatio: 1.2,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: slots.length,
          itemBuilder: (context, index) {
            final slot = slots[index];
            final isLocked = slot.status == 'locked';
            final isSelected = _selectedSlot?.id == slot.id;

            return GestureDetector(
              onTap: isLocked
                  ? null
                  : () {
                      setState(() {
                        _selectedSlot = isSelected ? null : slot;
                      });
                      widget.onSlotSelected(_selectedSlot);
                    },
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isLocked
                      ? Colors.red.withValues(alpha: 0.2)
                      : (isSelected
                          ? AppColors.primary.withValues(alpha: 0.4)
                          : Colors.green.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isLocked
                        ? Colors.red.shade300
                        : (isSelected ? AppColors.primary : Colors.green),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    "${slot.slotNumber}",
                    style: TextStyle(
                      color: isLocked
                          ? Colors.red.shade300
                          : (isSelected ? AppColors.primary : Colors.green),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
