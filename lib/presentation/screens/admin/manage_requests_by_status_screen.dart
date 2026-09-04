import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

void _showPasswordDeleteDialog({
  required BuildContext context,
  required String title,
  required String confirmMessage,
  required VoidCallback onConfirmed,
}) {
  final passwordController = TextEditingController();
  String? errorMessage;

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF161B22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.delete_forever, color: Colors.redAccent, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(confirmMessage, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.key, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("SECURITY PASSWORD", style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                            SizedBox(height: 2),
                            Text("IR ARMY", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Enter password (IR ARMY)...",
                    labelText: "Password",
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.white60),
                    filled: true,
                    fillColor: const Color(0xFF0D1117),
                    errorText: errorMessage,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("CANCEL", style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () {
                  final inputPass = passwordController.text.trim();
                  if (inputPass.toUpperCase() == "IR ARMY") {
                    Navigator.pop(dialogContext);
                    onConfirmed();
                  } else {
                    setState(() {
                      errorMessage = "Incorrect password! Required: IR ARMY";
                    });
                  }
                },
                child: const Text("DELETE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    },
  );
}

class ManageRequestsByStatusScreen extends StatelessWidget {
  final String status; // 'pending', 'success', 'failed'

  const ManageRequestsByStatusScreen({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Manage Requests"),
          actions: [
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
                tooltip: "Clear All Request History",
                onPressed: () {
                  final provider = Provider.of<TournamentProvider>(context, listen: false);
                  _showPasswordDeleteDialog(
                    context: context,
                    title: "Delete All Request History?",
                    confirmMessage: "Are you sure you want to permanently delete ALL deposit and withdrawal requests?",
                    onConfirmed: () async {
                      await provider.deleteAllDepositRequests();
                      await provider.deleteAllWithdrawalRequests();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("All request history deleted successfully!")),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: "DEPOSITS"),
              Tab(text: "WITHDRAWALS"),
            ],
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
          ),
        ),
        body: TabBarView(
          children: [
            _DepositRequestList(initialStatus: status),
            _WithdrawalRequestList(initialStatus: status),
          ],
        ),
      ),
    );
  }
}

class _DepositRequestList extends StatefulWidget {
  final String initialStatus;
  const _DepositRequestList({required this.initialStatus});

  @override
  State<_DepositRequestList> createState() => _DepositRequestListState();
}

class _DepositRequestListState extends State<_DepositRequestList> {
  late String _selectedStatus;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TournamentProvider>(context);

    return Column(
      children: [
        _buildStatusFilterChips(),
        _buildSearchField(),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: provider.depositRequests(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final all = snapshot.data ?? [];
              final filtered = all.where((req) {
                if ((req['status'] ?? 'pending') != _selectedStatus) return false;
                final txId = (req['transactionId'] ?? req['txId'] ?? "").toString().toLowerCase();
                final uId = (req['userId'] ?? "").toString().toLowerCase();
                return txId.contains(_searchQuery) || uId.contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _selectedStatus == 'success'
                            ? Icons.check_circle_outline
                            : _selectedStatus == 'failed'
                                ? Icons.cancel_outlined
                                : Icons.hourglass_empty,
                        size: 48,
                        color: Colors.white24,
                      ),
                      const SizedBox(height: 12),
                      Text("No $_selectedStatus deposit requests", style: const TextStyle(color: Colors.white60)),
                    ],
                  ),
                );
              }

              filtered.sort((a, b) {
                final aDt = a['dateTime'] != null ? (a['dateTime'] as dynamic).toDate() : DateTime(1970);
                final bDt = b['dateTime'] != null ? (b['dateTime'] as dynamic).toDate() : DateTime(1970);
                return bDt.compareTo(aDt);
              });

              final List<Map<String, dynamic>> todayRequests = [];
              final Map<String, List<Map<String, dynamic>>> pastDateGroups = {};
              final now = DateTime.now();

              for (final req in filtered) {
                final dt = req['dateTime'] != null ? (req['dateTime'] as dynamic).toDate() : null;
                if (dt == null || (dt.year == now.year && dt.month == now.month && dt.day == now.day)) {
                  todayRequests.add(req);
                } else {
                  final dateKey = DateFormat('dd MMM yyyy').format(dt);
                  pastDateGroups.putIfAbsent(dateKey, () => []).add(req);
                }
              }

              return ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  if (todayRequests.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.today, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            "TODAY (${todayRequests.length})",
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...todayRequests.map((req) => _buildDepositCard(context, req, provider, _selectedStatus)),
                  ],
                  if (pastDateGroups.isNotEmpty) ...[
                    if (todayRequests.isNotEmpty) const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8, top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.history, size: 16, color: Colors.white54),
                              SizedBox(width: 6),
                              Text(
                                "PAST HISTORY",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () {
                              _showPasswordDeleteDialog(
                                context: context,
                                title: "Delete All Past Deposits?",
                                confirmMessage: "Are you sure you want to delete all past deposit records for $_selectedStatus?",
                                onConfirmed: () async {
                                  await provider.deleteAllDepositRequests(status: _selectedStatus);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("All past deposit history deleted!")),
                                    );
                                  }
                                },
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.delete_forever, size: 14, color: Colors.redAccent),
                                  SizedBox(width: 4),
                                  Text(
                                    "DELETE ALL",
                                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...pastDateGroups.entries.map((entry) {
                      final dateKey = entry.key;
                      final items = entry.value;
                      return Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: const Color(0xFF10141A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Colors.white12),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: false,
                            leading: const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                            title: Text(
                              dateKey,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              "${items.length} request(s)",
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                            children: items
                                .map((req) => Padding(
                                      padding: const EdgeInsets.only(left: 4, right: 4, top: 4),
                                      child: _buildDepositCard(context, req, provider, _selectedStatus),
                                    ))
                                .toList(),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFF10141A),
      child: Row(
        children: [
          _filterChip("⏳ PENDING", 'pending', Colors.orangeAccent),
          const SizedBox(width: 8),
          _filterChip("✅ COMPLETED", 'success', AppColors.neonGreen),
          const SizedBox(width: 8),
          _filterChip("❌ REJECTED", 'failed', Colors.redAccent),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String statusKey, Color accentColor) {
    final isSelected = _selectedStatus == statusKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedStatus = statusKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? accentColor.withValues(alpha: 0.2) : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? accentColor : Colors.transparent, width: 1.5),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? accentColor : Colors.white60,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        decoration: InputDecoration(
          hintText: "Search by TX ID or User ID...",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: AppColors.surface,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
      ),
    );
  }

  Widget _buildDepositCard(BuildContext context, Map<String, dynamic> req, TournamentProvider provider, String status) {
    final date = (req['dateTime'] != null) ? DateFormat('dd MMM, hh:mm a').format(req['dateTime'].toDate()) : 'N/A';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ListTile(
            title: Row(
              children: [
                Text("₹${req['amount']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(width: 8),
                if (status == 'success')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                    child: const Text("COMPLETED ✓", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                else if (status == 'failed')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                    child: const Text("REJECTED ✕", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text("User: ${req['userId']}"),
                Text("TX ID: ${req['transactionId'] ?? req['txId'] ?? 'N/A'}"),
                Text("Date: $date"),
                if (status == 'failed' && req['rejectionReason'] != null)
                  Text("Reason: ${req['rejectionReason']}", style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status == 'pending') ...[
                  IconButton(icon: const Icon(Icons.check_circle, color: Colors.green, size: 26), onPressed: () => _confirmDeposit(context, provider, req['id'], 'success')),
                  IconButton(icon: const Icon(Icons.cancel, color: Colors.red, size: 26), onPressed: () => _confirmDeposit(context, provider, req['id'], 'failed')),
                ] else ...[
                  IconButton(
                    icon: Icon(status == 'failed' ? Icons.refresh : Icons.undo, color: Colors.amber, size: 22),
                    onPressed: () => _showResetDialog(context, provider, req['id'], true, status == 'success'),
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 22),
                  tooltip: "Delete Request",
                  onPressed: () {
                    _showPasswordDeleteDialog(
                      context: context,
                      title: "Delete Deposit Request?",
                      confirmMessage: "Are you sure you want to delete this deposit request?",
                      onConfirmed: () async {
                        await provider.deleteDepositRequest(req['id']);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deposit request deleted!")));
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          if (req['imageUrl'] != null && req['imageUrl'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: InkWell(
                onTap: () => _viewScreenshot(context, req['imageUrl']),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(req['imageUrl'], height: 120, width: double.infinity, fit: BoxFit.cover),
                ),
              ),
            )
          else if (req['screenshotUrl'] != null && req['screenshotUrl'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: InkWell(
                onTap: () => _viewScreenshot(context, req['screenshotUrl']),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(req['screenshotUrl'], height: 120, width: double.infinity, fit: BoxFit.cover),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _viewScreenshot(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InteractiveViewer(child: Image.network(url)),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CLOSE")),
          ],
        ),
      ),
    );
  }

  void _confirmDeposit(BuildContext context, TournamentProvider provider, String id, String status) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(status == 'success' ? "Approve Deposit?" : "Reject Deposit?"),
        content: status == 'failed' ? TextField(controller: reasonController, decoration: const InputDecoration(labelText: "Reason")) : const Text("Are you sure you want to approve this deposit?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await provider.updateDepositStatus(id, status, reason: reasonController.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(status.toUpperCase()),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, TournamentProvider provider, String id, bool isDeposit, bool isUndo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUndo ? "Undo Approval?" : "Reset to Pending?"),
        content: Text(isUndo ? "This will move it back to pending and reverse balance." : "This will move it back to pending."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await provider.resetDepositToPending(id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("CONFIRM"),
          ),
        ],
      ),
    );
  }
}

class _WithdrawalRequestList extends StatefulWidget {
  final String initialStatus;
  const _WithdrawalRequestList({required this.initialStatus});

  @override
  State<_WithdrawalRequestList> createState() => _WithdrawalRequestListState();
}

class _WithdrawalRequestListState extends State<_WithdrawalRequestList> {
  late String _selectedStatus;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialStatus;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TournamentProvider>(context);

    return Column(
      children: [
        _buildStatusFilterChips(),
        _buildSearchField(),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: provider.withdrawalRequests(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final all = snapshot.data ?? [];
              final filtered = all.where((req) {
                if ((req['status'] ?? 'pending') != _selectedStatus) return false;
                final details = (req['details'] ?? "").toString().toLowerCase();
                final uId = (req['userId'] ?? "").toString().toLowerCase();
                return details.contains(_searchQuery) || uId.contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _selectedStatus == 'success'
                            ? Icons.check_circle_outline
                            : _selectedStatus == 'failed'
                                ? Icons.cancel_outlined
                                : Icons.hourglass_empty,
                        size: 48,
                        color: Colors.white24,
                      ),
                      const SizedBox(height: 12),
                      Text("No $_selectedStatus withdrawal requests", style: const TextStyle(color: Colors.white60)),
                    ],
                  ),
                );
              }

              filtered.sort((a, b) {
                final aDt = a['dateTime'] != null ? (a['dateTime'] as dynamic).toDate() : DateTime(1970);
                final bDt = b['dateTime'] != null ? (b['dateTime'] as dynamic).toDate() : DateTime(1970);
                return bDt.compareTo(aDt);
              });

              final List<Map<String, dynamic>> todayRequests = [];
              final Map<String, List<Map<String, dynamic>>> pastDateGroups = {};
              final now = DateTime.now();

              for (final req in filtered) {
                final dt = req['dateTime'] != null ? (req['dateTime'] as dynamic).toDate() : null;
                if (dt == null || (dt.year == now.year && dt.month == now.month && dt.day == now.day)) {
                  todayRequests.add(req);
                } else {
                  final dateKey = DateFormat('dd MMM yyyy').format(dt);
                  pastDateGroups.putIfAbsent(dateKey, () => []).add(req);
                }
              }

              return ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  if (todayRequests.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.today, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            "TODAY (${todayRequests.length})",
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...todayRequests.map((req) => _buildWithdrawalCard(context, req, provider, _selectedStatus)),
                  ],
                  if (pastDateGroups.isNotEmpty) ...[
                    if (todayRequests.isNotEmpty) const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8, top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.history, size: 16, color: Colors.white54),
                              SizedBox(width: 6),
                              Text(
                                "PAST HISTORY",
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: () {
                              _showPasswordDeleteDialog(
                                context: context,
                                title: "Delete All Past Withdrawals?",
                                confirmMessage: "Are you sure you want to delete all past withdrawal records for $_selectedStatus?",
                                onConfirmed: () async {
                                  await provider.deleteAllWithdrawalRequests(status: _selectedStatus);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text("All past withdrawal history deleted!")),
                                    );
                                  }
                                },
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.delete_forever, size: 14, color: Colors.redAccent),
                                  SizedBox(width: 4),
                                  Text(
                                    "DELETE ALL",
                                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...pastDateGroups.entries.map((entry) {
                      final dateKey = entry.key;
                      final items = entry.value;
                      return Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: const Color(0xFF10141A),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Colors.white12),
                          ),
                          child: ExpansionTile(
                            initiallyExpanded: false,
                            leading: const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                            title: Text(
                              dateKey,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              "${items.length} request(s)",
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                            children: items
                                .map((req) => Padding(
                                      padding: const EdgeInsets.only(left: 4, right: 4, top: 4),
                                      child: _buildWithdrawalCard(context, req, provider, _selectedStatus),
                                    ))
                                .toList(),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFF10141A),
      child: Row(
        children: [
          _filterChip("⏳ PENDING", 'pending', Colors.orangeAccent),
          const SizedBox(width: 8),
          _filterChip("✅ COMPLETED", 'success', AppColors.neonGreen),
          const SizedBox(width: 8),
          _filterChip("❌ REJECTED", 'failed', Colors.redAccent),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String statusKey, Color accentColor) {
    final isSelected = _selectedStatus == statusKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedStatus = statusKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? accentColor.withValues(alpha: 0.2) : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? accentColor : Colors.transparent, width: 1.5),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? accentColor : Colors.white60,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        decoration: InputDecoration(
          hintText: "Search by Details or User ID...",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: AppColors.surface,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
      ),
    );
  }

  Widget _buildWithdrawalCard(BuildContext context, Map<String, dynamic> req, TournamentProvider provider, String status) {
    final date = (req['dateTime'] != null) ? DateFormat('dd MMM, hh:mm a').format(req['dateTime'].toDate()) : 'N/A';
    final scannerUrl = req['scannerUrl'] ?? req['scannerImage'] ?? req['qrUrl'] ?? req['qrCodeUrl'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            title: Row(
              children: [
                Text("₹${req['amount']} via ${req['method']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                if (status == 'success')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                    child: const Text("APPROVED ✓", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                else if (status == 'failed')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                    child: const Text("REJECTED ✕", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text("User: ${req['userId']}"),
                if ((req['details'] ?? '').toString().isNotEmpty)
                  Text("Details: ${req['details']}"),
                Text("Date: $date"),
                if (status == 'failed' && req['rejectionReason'] != null)
                  Text("Reason: ${req['rejectionReason']}", style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (status == 'pending') ...[
                  IconButton(icon: const Icon(Icons.check_circle, color: Colors.green, size: 26), onPressed: () => _confirmWithdrawal(context, provider, req['id'], 'success')),
                  IconButton(icon: const Icon(Icons.cancel, color: Colors.red, size: 26), onPressed: () => _confirmWithdrawal(context, provider, req['id'], 'failed')),
                ] else ...[
                  IconButton(
                    icon: Icon(status == 'failed' ? Icons.refresh : Icons.undo, color: Colors.amber, size: 22),
                    onPressed: () => _showResetDialog(context, provider, req['id'], false, status == 'success'),
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 22),
                  tooltip: "Delete Request",
                  onPressed: () {
                    _showPasswordDeleteDialog(
                      context: context,
                      title: "Delete Withdrawal Request?",
                      confirmMessage: "Are you sure you want to delete this withdrawal request?",
                      onConfirmed: () async {
                        await provider.deleteWithdrawalRequest(req['id']);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Withdrawal request deleted!")));
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          if (scannerUrl != null && scannerUrl.toString().trim().isNotEmpty) ...[
            const Divider(height: 1, color: Colors.white10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      backgroundColor: const Color(0xFF10141A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.qr_code_scanner, color: AppColors.primary, size: 20),
                                SizedBox(width: 8),
                                Text("USER UPI QR SCANNER", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 14)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                scannerUrl.toString(),
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Text("Error loading QR image", style: TextStyle(color: Colors.redAccent)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                                onPressed: () => Navigator.pop(context),
                                child: const Text("CLOSE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10141A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.qr_code_2, size: 22, color: AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("UPI QR SCANNER UPLOADED", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 11)),
                          SizedBox(height: 2),
                          Text("Tap to view / scan QR", style: TextStyle(color: Colors.white60, fontSize: 10)),
                        ],
                      ),
                      const Spacer(),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          scannerUrl.toString(),
                          height: 42,
                          width: 42,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 24, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmWithdrawal(BuildContext context, TournamentProvider provider, String id, String status) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(status == 'success' ? "Approve Withdrawal?" : "Reject Withdrawal?"),
        content: status == 'failed' ? TextField(controller: reasonController, decoration: const InputDecoration(labelText: "Reason")) : const Text("Are you sure you want to approve this withdrawal?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await provider.updateWithdrawalStatus(id, status, reason: reasonController.text);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(status.toUpperCase()),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, TournamentProvider provider, String id, bool isDeposit, bool isUndo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUndo ? "Undo Approval?" : "Reset to Pending?"),
        content: Text(isUndo ? "This will move it back to pending and reverse balance if needed." : "This will move it back to pending."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (isUndo) {
                if (isDeposit) {
                  await provider.resetDepositToPending(id);
                } else {
                  await provider.undoWithdrawalApproval(id);
                }
              } else {
                if (isDeposit) {
                  await provider.resetDepositToPending(id);
                } else {
                  await provider.resetWithdrawalToPending(id);
                }
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("CONFIRM"),
          ),
        ],
      ),
    );
  }
}
