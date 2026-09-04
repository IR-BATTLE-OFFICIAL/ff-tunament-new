import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class ManageDepositsScreen extends StatefulWidget {
  const ManageDepositsScreen({super.key});

  @override
  State<ManageDepositsScreen> createState() => _ManageDepositsScreenState();
}

class _ManageDepositsScreenState extends State<ManageDepositsScreen> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TournamentProvider>(context);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Deposit Requests"),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(110),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search by TX ID or User ID...",
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
          stream: provider.depositRequests(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final allRequests = snapshot.data ?? [];
            if (allRequests.isEmpty) {
              return const Center(child: Text("No deposit requests"));
            }

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

      final txId = (req['transactionId'] ?? "").toString().toLowerCase();
      final uId = (req['userId'] ?? "").toString().toLowerCase();
      return txId.contains(_searchQuery) || uId.contains(_searchQuery);
    }).toList();

    if (requests.isEmpty) {
      return Center(child: Text("No $status requests found"));
    }

    return ListView.builder(
      itemCount: requests.length,
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      itemBuilder: (context, index) {
        final req = requests[index];
        final type = req['type'] ?? 'manual';
        final date = (req['dateTime'] != null) 
            ? DateFormat('dd MMM, hh:mm a').format(req['dateTime'].toDate())
            : 'N/A';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          child: Column(
            children: [
              ListTile(
                title: Text("₹${req['amount']} (${type.toUpperCase()})", style: const TextStyle(
                  fontWeight: FontWeight.bold
                )),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("TX ID: ${req['transactionId']}"),
                    Text("User ID: ${req['userId']}"),
                    if (req['voucherData'] != null)
                      Text("Voucher: ${req['voucherData']['code']} (+${req['voucherData']['value']}%)", 
                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    if (status == 'failed' && req['rejectionReason'] != null)
                      Text("Reason: ${req['rejectionReason']}", style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontStyle: FontStyle.italic)),
                    Text("Date: $date"),
                  ],
                ),
                trailing: status == 'pending' ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => _confirmAction(context, provider, req['id'], 'success'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _confirmAction(context, provider, req['id'], 'failed'),
                    ),
                  ],
                ) : IconButton(
                  icon: Icon(status == 'failed' ? Icons.refresh : Icons.undo, color: Colors.amber),
                  tooltip: status == 'failed' ? "Reset to Pending" : "Undo Approval",
                  onPressed: () => _showResetDialog(context, provider, req['id'], status == 'success'),
                ),
              ),
              if (req['screenshotUrl'] != null && req['screenshotUrl'].isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: InkWell(
                    onTap: () => _viewScreenshot(context, req['screenshotUrl']),
                    child: Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          req['screenshotUrl'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _viewScreenshot(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.black45,
              elevation: 0,
              leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              title: const Text("Payment Screenshot"),
            ),
            Expanded(
              child: InteractiveViewer(
                child: Image.network(url),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context, TournamentProvider provider, String id, bool isUndo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUndo ? "Undo Approval?" : "Reset to Pending?"),
        content: Text(isUndo 
          ? "This will move the request back to Pending and DEDUCT the amount from user balance." 
          : "This will move the request back to Pending tab for re-evaluation."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await provider.resetDepositToPending(id);
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: Text(isUndo ? "UNDO" : "RESET"),
          ),
        ],
      ),
    );
  }

  void _confirmAction(BuildContext context, TournamentProvider provider, String id, String status) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${status == 'success' ? 'Approve' : 'Reject'} Deposit?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Are you sure you want to ${status == 'success' ? 'approve' : 'reject'} this request?"),
            if (status == 'failed') ...[
              const SizedBox(height: 15),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: "Rejection Reason",
                  hintText: "e.g. Invalid Screenshot, Wrong ID...",
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
              await provider.updateDepositStatus(id, status, reason: reasonController.text.trim());
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
