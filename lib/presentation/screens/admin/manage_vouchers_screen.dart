import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class ManageVouchersScreen extends StatefulWidget {
  const ManageVouchersScreen({super.key});

  @override
  State<ManageVouchersScreen> createState() => _ManageVouchersScreenState();
}

class _ManageVouchersScreenState extends State<ManageVouchersScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TournamentProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Manage Vouchers")),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddVoucherDialog(context, provider),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: provider.vouchers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("No vouchers created yet"));

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final v = snapshot.data![index];
              final expiry = (v['expiryDate'] as Timestamp).toDate();
              final isExpired = DateTime.now().isAfter(expiry);

              return Card(
                color: AppColors.surface,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isExpired ? Colors.red.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                    child: Icon(
                      v['type'] == 'free_entry' ? Icons.confirmation_number : Icons.card_giftcard,
                      color: isExpired ? Colors.red : AppColors.primary,
                    ),
                  ),
                  title: Text(v['code'], style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${v['type'].toString().replaceAll('_', ' ').toUpperCase()} | Value: ${v['value']}${v['type'] == 'deposit_bonus' ? '%' : '₹'}"),
                      Text("Expires: ${DateFormat('dd MMM yyyy').format(expiry)}", 
                        style: TextStyle(color: isExpired ? Colors.red : Colors.grey, fontSize: 11)),
                      Text("Used: ${v['usedCount']}/${v['usageLimit']}", style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                    onPressed: () => _confirmDeleteVoucher(context, provider, v),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDeleteVoucher(BuildContext context, TournamentProvider provider, Map<String, dynamic> v) {
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
            Text("Delete Voucher?", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          "Are you sure you want to delete voucher '${v['code']}'?",
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
              await provider.deleteVoucher(v['id']);
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAddVoucherDialog(BuildContext context, TournamentProvider provider) {
    final codeController = TextEditingController();
    final valueController = TextEditingController();
    final limitController = TextEditingController(text: "100");
    final minAmountController = TextEditingController(text: "0");
    String type = 'deposit_bonus';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    bool sendNotification = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Create New Voucher"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: "Voucher Code", hintText: "E.g. FREE50"),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: type,
                  items: [
                    {'label': 'Deposit Bonus (%)', 'value': 'deposit_bonus'},
                    {'label': 'Free Entry (Match)', 'value': 'free_entry'},
                    {'label': 'Discount (₹)', 'value': 'discount'},
                  ].map((e) => DropdownMenuItem(value: e['value'], child: Text(e['label']!))).toList(),
                  onChanged: (v) => setState(() => type = v!),
                  decoration: const InputDecoration(labelText: "Voucher Type"),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: valueController,
                  decoration: InputDecoration(
                    labelText: type == 'deposit_bonus' ? "Bonus Percentage (%)" : "Discount Amount (₹)",
                    hintText: type == 'free_entry' ? "0 (Auto)" : "Enter value",
                  ),
                  keyboardType: TextInputType.number,
                  enabled: type != 'free_entry',
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: limitController,
                  decoration: const InputDecoration(labelText: "Total Usage Limit"),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 15),
                CheckboxListTile(
                  title: const Text("Send Announcement", style: TextStyle(fontSize: 14)),
                  value: sendNotification,
                  onChanged: (v) => setState(() => sendNotification = v!),
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primary,
                ),
                const SizedBox(height: 5),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Expiry Date", style: TextStyle(fontSize: 14, color: Colors.grey)),
                  subtitle: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today, size: 20),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2101),
                    );
                    if (picked != null) setState(() => selectedDate = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                final code = codeController.text.trim().toUpperCase();
                if (code.isEmpty) return;
                
                final value = type == 'free_entry' ? 0.0 : (double.tryParse(valueController.text) ?? 0.0);

                await provider.createVoucher({
                  'code': code,
                  'type': type,
                  'value': value,
                  'minAmount': double.tryParse(minAmountController.text) ?? 0.0,
                  'usageLimit': int.tryParse(limitController.text) ?? 100,
                  'usedCount': 0,
                  'usedBy': [],
                  'expiryDate': Timestamp.fromDate(selectedDate),
                  'isActive': true,
                });

                if (sendNotification) {
                  final notification = {
                    'title': 'New Coupon: $code 🎁',
                    'message': 'Code: $code mil gaya! Jald use karein.',
                    'dateTime': Timestamp.now(),
                    'type': 'general',
                  };
                  await FirebaseFirestore.instance.collection('notifications').add(notification);
                  
                  if (context.mounted) {
                    await Provider.of<AuthProvider>(context, listen: false).adminIncrementAllUsersUnreadCount();
                  }
                }

                if (context.mounted) Navigator.pop(context);
              },
              child: const Text("CREATE & SEND"),
            ),
          ],
        ),
      ),
    );
  }
}
