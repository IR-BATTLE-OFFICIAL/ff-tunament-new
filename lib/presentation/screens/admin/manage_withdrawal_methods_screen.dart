import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:provider/provider.dart';

class ManageWithdrawalMethodsScreen extends StatefulWidget {
  const ManageWithdrawalMethodsScreen({super.key});

  @override
  State<ManageWithdrawalMethodsScreen> createState() => _ManageWithdrawalMethodsScreenState();
}

class _ManageWithdrawalMethodsScreenState extends State<ManageWithdrawalMethodsScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TournamentProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Withdrawal Methods")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMethodDialog(context, provider),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: provider.withdrawalMethods(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No withdrawal methods set yet"));

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final method = snapshot.data![index];
              final bool isActive = method['isActive'] ?? true;

              return Card(
                color: AppColors.surface,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Icon(_getIconForMethod(method['name']), color: AppColors.primary),
                  ),
                  title: Text(method['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${method['instruction'] ?? "No instructions"}${method['requireScanner'] == true ? "\n(QR Required)" : ""}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: isActive,
                        onChanged: (val) {
                          provider.updateWithdrawalMethod(method['id'], {'isActive': val});
                        },
                        activeColor: AppColors.primary,
                      ),
                      IconButton(
                        icon: Icon(
                          method['requireScanner'] == true ? Icons.qr_code_scanner : Icons.qr_code_2,
                          color: method['requireScanner'] == true ? AppColors.primary : Colors.grey,
                        ),
                        onPressed: () {
                          provider.updateWithdrawalMethod(method['id'], {'requireScanner': !(method['requireScanner'] ?? false)});
                        },
                        tooltip: "Toggle QR Requirement",
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                        onPressed: () => _confirmDeleteMethod(context, provider, method),
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

  void _confirmDeleteMethod(BuildContext context, TournamentProvider provider, Map<String, dynamic> method) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF10141A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text("Delete Method?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          "Are you sure you want to delete withdrawal method '${method['name']}'?",
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await provider.deleteWithdrawalMethod(method['id']);
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  IconData _getIconForMethod(String name) {
    name = name.toLowerCase();
    if (name.contains('upi')) return Icons.account_balance_wallet;
    if (name.contains('bank')) return Icons.account_balance;
    if (name.contains('paytm')) return Icons.payment;
    if (name.contains('phonepe')) return Icons.smartphone;
    return Icons.money;
  }

  void _showAddMethodDialog(BuildContext context, TournamentProvider provider) {
    final nameController = TextEditingController();
    final instructionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Withdrawal Method"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Method Name", hintText: "E.g. PayTM, UPI, Bank Transfer"),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: instructionController,
              decoration: const InputDecoration(labelText: "Instruction for User", hintText: "E.g. Enter PayTM Number"),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              await provider.addWithdrawalMethod({
                'name': nameController.text.trim(),
                'instruction': instructionController.text.trim(),
                'isActive': true,
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("ADD"),
          ),
        ],
      ),
    );
  }
}
