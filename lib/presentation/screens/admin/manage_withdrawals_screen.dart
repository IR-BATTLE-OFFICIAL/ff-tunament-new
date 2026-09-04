import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class ManageWithdrawalsScreen extends StatefulWidget {
  const ManageWithdrawalsScreen({super.key});

  @override
  State<ManageWithdrawalsScreen> createState() => _ManageWithdrawalsScreenState();
}

class _ManageWithdrawalsScreenState extends State<ManageWithdrawalsScreen> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TournamentProvider>(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Withdrawal Requests"),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(110),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search by Details or User ID...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = "";
                              });
                            },
                          )
                        : null,
                      filled: true,
                      fillColor: AppColors.surface,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: "Pending"),
                    Tab(text: "Approved"),
                    Tab(text: "Rejected"),
                  ],
                  indicatorColor: AppColors.primary,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.grey,
                ),
              ],
            ),
          ),
        ),
        body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: provider.withdrawalRequests(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text("No requests found"));
            }

            final allRequests = snapshot.data!;
            return TabBarView(
              children: [
                _buildRequestList(allRequests, 'pending', provider),
                _buildRequestList(allRequests, 'success', provider),
                _buildRequestList(allRequests, 'failed', provider),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRequestList(List<Map<String, dynamic>> allRequests, String status, TournamentProvider provider) {
    final requests = allRequests.where((req) {
      final reqStatus = req['status'] ?? 'pending';
      if (reqStatus != status) return false;

      final details = (req['details'] ?? "").toString().toLowerCase();
      final uId = (req['userId'] ?? "").toString().toLowerCase();
      return details.contains(_searchQuery) || uId.contains(_searchQuery);
    }).toList();

    if (requests.isEmpty) {
      return Center(child: Text("No $status requests found"));
    }

    return ListView.builder(
      itemCount: requests.length,
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      itemBuilder: (context, index) {
        final req = requests[index];
        final method = req['method'] ?? 'UPI';
        final details = req['details'] ?? 'N/A';
        final scannerUrl = req['scannerUrl'];
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              ListTile(
                title: Text("₹${req['amount']} via $method"),
                subtitle: Text("Details: $details\nUser ID: ${req['userId']}\nDate: ${DateFormat('dd MMM, hh:mm a').format(req['dateTime'].toDate())}"),
                trailing: status == 'pending' ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => _showConfirmDialog(context, provider, req['id'], 'success'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _showConfirmDialog(context, provider, req['id'], 'failed'),
                    ),
                  ],
                ) : IconButton(
                  icon: Icon(status == 'failed' ? Icons.refresh : Icons.undo, color: Colors.amber),
                  tooltip: status == 'failed' ? "Reset to Pending" : "Undo Approval",
                  onPressed: () => _showResetDialog(context, provider, req['id'], status == 'success'),
                ),
              ),
              if (status == 'failed' && req['rejectionReason'] != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Reason: ${req['rejectionReason']}",
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
                ),
              if (scannerUrl != null) ...[
                const Divider(height: 0),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.network(scannerUrl),
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
                            ],
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code, size: 20, color: AppColors.primary),
                        const SizedBox(width: 10),
                        const Text("VIEW QR SCANNER", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                        const Spacer(),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(scannerUrl, height: 40, width: 40, fit: BoxFit.cover),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showResetDialog(BuildContext context, TournamentProvider provider, String id, bool isUndo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUndo ? "Undo Approval?" : "Reset to Pending?"),
        content: Text(isUndo 
          ? "This will move the request back to Pending. Note: Balance was already deducted when it was pending." 
          : "This will move the request back to Pending tab. Note: The amount will be DEDUCTED from user balance again as it was refunded when rejected."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              try {
                if (isUndo) {
                  await provider.undoWithdrawalApproval(id);
                } else {
                  await provider.resetWithdrawalToPending(id);
                }
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: Text(isUndo ? "UNDO" : "RESET"),
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog(BuildContext context, TournamentProvider provider, String id, String status) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(status == 'success' ? "Approve Withdrawal?" : "Reject Withdrawal?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Are you sure you want to mark this request as ${status.toUpperCase()}?"),
            if (status == 'failed') ...[
              const SizedBox(height: 15),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: "Rejection Reason",
                  hintText: "e.g. Invalid UPI, Wrong Name...",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (status == 'failed' && reasonController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please provide a reason")));
                return;
              }
              await provider.updateWithdrawalStatus(id, status, reason: reasonController.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: status == 'success' ? Colors.green : Colors.red),
            child: Text(status == 'success' ? "APPROVE" : "REJECT"),
          ),
        ],
      ),
    );
  }
}
