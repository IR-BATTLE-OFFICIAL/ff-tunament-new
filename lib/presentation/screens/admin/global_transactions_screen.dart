import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class GlobalTransactionsScreen extends StatelessWidget {
  const GlobalTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TournamentProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Global Transactions")),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: provider.allTransactions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No transactions found"));
          }

          final txs = snapshot.data!;

          return ListView.builder(
            itemCount: txs.length,
            itemBuilder: (context, index) {
              final tx = txs[index];
              final type = tx['type'] ?? 'unknown';
              final status = tx['status'] ?? 'success';
              final amount = (tx['amount'] ?? 0.0).toDouble();
              final date = (tx['dateTime'] != null) 
                ? (tx['dateTime'] as dynamic).toDate() 
                : DateTime.now();
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getTypeColor(type).withOpacity(0.2),
                    child: Icon(_getTypeIcon(type), color: _getTypeColor(type)),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatType(type),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "₹$amount",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getAmountColor(type),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(tx['description'] ?? "No description", style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('dd MMM, hh:mm a').format(date),
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                          _buildStatusBadge(status),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatType(String type) {
    return type.replaceAll('_', ' ').toUpperCase();
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'deposit': return Icons.add_circle_outline;
      case 'withdrawal': return Icons.remove_circle_outline;
      case 'prize': return Icons.emoji_events;
      case 'entry_fee': return Icons.sports_esports;
      case 'refund': return Icons.history;
      case 'referral_reward':
      case 'referral_bonus': return Icons.people;
      default: return Icons.payment;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'deposit': return Colors.green;
      case 'withdrawal': return Colors.red;
      case 'prize': return Colors.amber;
      case 'entry_fee': return Colors.blue;
      case 'refund': return Colors.orange;
      case 'referral_reward':
      case 'referral_bonus': return Colors.purple;
      default: return Colors.grey;
    }
  }

  Color _getAmountColor(String type) {
    if (type == 'deposit' || type == 'prize' || type == 'refund' || type == 'referral_reward' || type == 'referral_bonus') {
      return Colors.greenAccent;
    }
    return Colors.redAccent;
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'success': color = Colors.green; break;
      case 'pending': color = Colors.orange; break;
      case 'failed': color = Colors.red; break;
      default: color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.5),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }
}
