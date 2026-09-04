import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/data/models/tournament_model.dart';
import 'package:ff_arena/data/models/registration_model.dart';
import 'package:ff_arena/presentation/providers/auth_provider.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:provider/provider.dart';

class JoinTournamentScreen extends StatefulWidget {
  final TournamentModel tournament;
  final int selectedSlot; // Slot number chosen by user (0 = not chosen)

  const JoinTournamentScreen({super.key, required this.tournament, this.selectedSlot = 0});

  @override
  State<JoinTournamentScreen> createState() => _JoinTournamentScreenState();
}

class _JoinTournamentScreenState extends State<JoinTournamentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ffUidController = TextEditingController();
  final _ffUsernameController = TextEditingController();
  final _voucherController = TextEditingController();
  bool _isLoading = false;
/*
                controller: _ffUsernameController,
                decoration: InputDecoration(
                  labelText: "Free Fire Username",
                  prefixIcon: Icon(Icons.person, color: AppColors.accent, size: 18),
                  suffixIcon: (user?.name ?? '').isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.refresh, size: 18, color: AppColors.textMuted),
                          tooltip: "Reset to profile name",
                          onPressed: () => setState(() => _ffUsernameController.text = user?.name ?? ''),
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  helperText: "Your exact in-game name",
                ),
                validator: (v) => v!.trim().isEmpty ? "Free Fire Username is required" : null,
              ),

              // ── Voucher Section ──
              if (!widget.tournament.isFree) ...[
                const SizedBox(height: 28),
                Row(
                  children: [
                    Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.neonGreen, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 8),
                    const Text("APPLY COUPON", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white, letterSpacing: 0.8)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _voucherController,
                        decoration: InputDecoration(
                          hintText: "Enter Coupon Code",
                          prefixIcon: const Icon(Icons.local_offer_outlined, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        textCapitalization: TextCapitalization.characters,
                        enabled: _appliedVoucher == null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _appliedVoucher != null
                          ? () => setState(() => _appliedVoucher = null)
                          : () => _applyVoucher(user?.uid ?? ''),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _appliedVoucher != null ? Colors.redAccent : Colors.blue,
                        minimumSize: const Size(90, 55),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_appliedVoucher != null ? "REMOVE" : "APPLY",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                if (_appliedVoucher != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.neonGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.neonGreen.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppColors.neonGreen, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            "Coupon '${_voucherController.text}' applied! Save ₹${(_appliedVoucher!['type'] == 'free_entry' ? widget.tournament.entryFee : (_appliedVoucher!['value'] as num).toDouble()).toStringAsFixed(0)}",
                            style: const TextStyle(color: AppColors.neonGreen, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: 40),

              // ── Confirm & Pay Button ──
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _handleJoin(user?.uid ?? '', user?.profilePic),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.tournament.isFree ? AppColors.neonGreen : AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.tournament.isFree ? Icons.card_giftcard : Icons.payment,
                              color: Colors.black,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.tournament.isFree
                                  ? "JOIN FOR FREE"
                                  : "CONFIRM & PAY  ₹${currentEntryFee.toStringAsFixed(0)}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _handleJoin(String userId, String? userProfilePic) async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final registration = RegistrationModel(
          id: '',
          tournamentId: widget.tournament.id,
          userId: userId,
          userName: _ffUsernameController.text.trim(),
          userProfilePic: userProfilePic,
          ffUid: _ffUidController.text.trim(),
          teamName: _ffUsernameController.text.trim(),
          playerDetails: [],
          registrationDate: DateTime.now(),
          status: 'confirmed',
          slotNumber: widget.selectedSlot,
        );

        await Provider.of<TournamentProvider>(context, listen: false)
            .joinTournament(registration, widget.tournament.isFree ? 0.0 : widget.tournament.entryFee,
                voucherId: widget.tournament.isFree ? null : _appliedVoucher?['id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Joined Successfully! 🎉"), backgroundColor: Colors.green),
          );
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.redAccent),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }
}

*/
  Map<String, dynamic>? _appliedVoucher;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).userModel;
      if (user != null) {
        if (_ffUidController.text.isEmpty && (user.ffUid ?? '').isNotEmpty) {
          _ffUidController.text = user.ffUid!;
        }
        if (_ffUsernameController.text.isEmpty && (user.name ?? '').isNotEmpty) {
          _ffUsernameController.text = user.name!;
        }
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ffUidController.dispose();
    _ffUsernameController.dispose();
    _voucherController.dispose();
    super.dispose();
  }

  void _applyVoucher(String userId) async {
    final code = _voucherController.text.trim();
    if (code.isEmpty) return;

    try {
      final v = await Provider.of<TournamentProvider>(context, listen: false)
          .validateVoucher(code, userId, 'any'); // Can be free_entry or discount

      if (v['type'] == 'deposit_bonus') {
        throw Exception("This voucher is only for deposits");
      }

      setState(() {
        _appliedVoucher = v;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Voucher applied successfully!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).userModel;
    double currentEntryFee = widget.tournament.entryFee;
    
    if (_appliedVoucher != null) {
      if (_appliedVoucher!['type'] == 'free_entry') {
        currentEntryFee = 0;
      } else if (_appliedVoucher!['type'] == 'discount') {
        currentEntryFee = (widget.tournament.entryFee - (_appliedVoucher!['value'] as num).toDouble()).clamp(0, double.infinity);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Confirm Registration")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.tournament.isFree ? Colors.green.withOpacity(0.1) : Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: widget.tournament.isFree ? Border.all(color: Colors.green, width: 1.5) : null,
                ),
                child: Column(
                  children: [
                    Text(widget.tournament.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    if (widget.tournament.isFree) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.card_giftcard, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text("FREE ENTRY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Entry Fee: ", style: TextStyle(color: Colors.grey)),
                          if (_appliedVoucher != null) ...[
                            Text("₹${widget.tournament.entryFee}", style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)),
                            const SizedBox(width: 8),
                          ],
                          Text("₹${currentEntryFee.toStringAsFixed(0)}", style: const TextStyle(color: Colors.green, fontSize: 20, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Show selected slot badge
              if (widget.selectedSlot > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade700, width: 1.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.event_seat, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "Your Selected Slot: #${widget.selectedSlot}",
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 30),
              TextFormField(
                controller: _ffUidController,
                decoration: InputDecoration(
                  labelText: "Free Fire UID",
                  prefixIcon: const Icon(Icons.fingerprint),
                  suffixIcon: (user?.ffUid ?? '').isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.refresh, size: 18, color: AppColors.textMuted),
                          tooltip: "Reset to profile UID",
                          onPressed: () => setState(() => _ffUidController.text = user?.ffUid ?? ''),
                        )
                      : null,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => v!.trim().isEmpty ? "Free Fire UID is required" : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _ffUsernameController,
                decoration: InputDecoration(
                  labelText: "Free Fire Name",
                  prefixIcon: const Icon(Icons.person),
                  suffixIcon: (user?.name ?? '').isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.refresh, size: 18, color: AppColors.textMuted),
                          tooltip: "Reset to profile name",
                          onPressed: () => setState(() => _ffUsernameController.text = user?.name ?? ''),
                        )
                      : null,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => v!.trim().isEmpty ? "Free Fire Name is required" : null,
              ),
              if (!widget.tournament.isFree) ...[
                const SizedBox(height: 30),
                const Text("Apply Coupon", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _voucherController,
                        decoration: const InputDecoration(hintText: "Enter Code", border: OutlineInputBorder()),
                        textCapitalization: TextCapitalization.characters,
                        enabled: _appliedVoucher == null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _appliedVoucher != null ? () => setState(() => _appliedVoucher = null) : () => _applyVoucher(user?.uid ?? ''),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _appliedVoucher != null ? Colors.red : Colors.blue,
                        minimumSize: const Size(80, 55),
                      ),
                      child: Text(_appliedVoucher != null ? "REMOVE" : "APPLY"),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _handleJoin(user?.uid ?? '', user?.name, user?.profilePic),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.tournament.isFree ? Colors.green : Colors.amber.shade700,
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(widget.tournament.isFree ? Icons.card_giftcard : Icons.payment, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            widget.tournament.isFree ? "JOIN FOR FREE" : "CONFIRM & PAY",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          ),
                        ],
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleJoin(String userId, String? userName, String? userProfilePic) async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final registration = RegistrationModel(
          id: '',
          tournamentId: widget.tournament.id,
          userId: userId,
          userName: _ffUsernameController.text.trim(),
          userProfilePic: userProfilePic,
          ffUid: _ffUidController.text.trim(),
          teamName: _ffUsernameController.text.trim(),
          playerDetails: [],
          registrationDate: DateTime.now(),
          status: 'confirmed',
          slotNumber: widget.selectedSlot,
        );

        await Provider.of<TournamentProvider>(context, listen: false)
            .joinTournament(registration, widget.tournament.isFree ? 0.0 : widget.tournament.entryFee, voucherId: widget.tournament.isFree ? null : _appliedVoucher?['id']);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Joined Successfully!"), backgroundColor: Colors.green));
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.redAccent));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }
}
