import 'package:flutter/material.dart';

class PrizeBreakdownWidget extends StatelessWidget {
  final List<Map<String, dynamic>> prizeBreakdown;

  const PrizeBreakdownWidget({super.key, required this.prizeBreakdown});

  @override
  Widget build(BuildContext context) {
    if (prizeBreakdown.isEmpty) return const SizedBox.shrink();

    // Sort by rank to ensure display order
    final sortedBreakdown = List<Map<String, dynamic>>.from(prizeBreakdown)
      ..sort((a, b) => (a['rank'] as int).compareTo(b['rank'] as int));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Prize Breakdown",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Table(
            border: TableBorder.all(color: Colors.white24),
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(2),
            },
            children: [
              const TableRow(
                decoration: BoxDecoration(color: Colors.white12),
                children: [
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text("Rank", style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text("Prize", style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                ],
              ),
              ...sortedBreakdown.map((prize) {
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("${prize['rank']}", textAlign: TextAlign.center),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("₹${(prize['amount'] as num).toStringAsFixed(0)}", textAlign: TextAlign.center),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
