import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/data/models/tournament_model.dart';
import 'package:ff_arena/data/models/registration_model.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:provider/provider.dart';

class UploadResultsScreen extends StatefulWidget {
  final TournamentModel tournament;
  const UploadResultsScreen({super.key, required this.tournament});

  @override
  State<UploadResultsScreen> createState() => _UploadResultsScreenState();
}

class _UploadResultsScreenState extends State<UploadResultsScreen> {
  final List<Map<String, dynamic>> _results = [];
  final Map<String, TextEditingController> _fieldControllers = {};
  final Map<String, ValueNotifier<double>> _totalPrizeNotifiers = {};
  bool _isLoading = false;

  TextEditingController _controllerFor(String resultId, String field) {
    return _fieldControllers.putIfAbsent(
      '$resultId-$field',
      () => TextEditingController(),
    );
  }

  ValueNotifier<double> _totalNotifierFor(String resultId) {
    return _totalPrizeNotifiers.putIfAbsent(resultId, () => ValueNotifier<double>(0));
  }

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
    final provider = Provider.of<TournamentProvider>(context, listen: false);
    final results = await provider.results(widget.tournament.id).first;
    
    // If results already exist, populate fields for editing
    if (results.isNotEmpty) {
      final participants = await provider.participants(widget.tournament.id).first;
      for (var p in participants) {
        final existingRes = results.firstWhere((r) => r['userId'] == p.userId, orElse: () => {});
        final res = {
          'userId': p.userId,
          'playerName': p.userName,
          'ffUid': p.ffUid,
          'rank': (existingRes['rank'] as num?)?.toInt() ?? 0,
          'kills': (existingRes['kills'] as num?)?.toInt() ?? 0,
          'positionPrize': (existingRes['positionPrize'] as num?)?.toDouble() ?? 0.0,
          'killPrize': (existingRes['killPrize'] as num?)?.toDouble() ?? 0.0,
          'booyahPrize': (existingRes['booyahPrize'] as num?)?.toDouble() ?? 0.0,
          'prizeWon': (existingRes['prizeWon'] as num?)?.toDouble() ?? 0.0,
        };
        _results.add(res);
        _controllerFor(res['userId'] as String, 'rank').text = res['rank'].toString();
        _controllerFor(res['userId'] as String, 'kills').text = res['kills'].toString();
        _controllerFor(res['userId'] as String, 'positionPrize').text = res['positionPrize'].toString();
        _controllerFor(res['userId'] as String, 'killPrize').text = res['killPrize'].toString();
        _controllerFor(res['userId'] as String, 'booyahPrize').text = res['booyahPrize'].toString();
        _totalNotifierFor(res['userId'] as String).value = (res['prizeWon'] as num).toDouble();
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (final controller in _fieldControllers.values) {
      controller.dispose();
    }
    for (final notifier in _totalPrizeNotifiers.values) {
      notifier.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tournamentProvider = Provider.of<TournamentProvider>(context);
    final perKillRate = widget.tournament.perKillPrize;
    final isLive = widget.tournament.status == 'live';

    return Scaffold(
      appBar: AppBar(
        title: Text(isLive ? "Live Match: Rank & Kills" : "Results: ${widget.tournament.title}"),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _submitResults,
            ),
        ],
      ),
      body: Column(
        children: [
          // Per-Kill rate info badge
          if (perKillRate > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Tournament Per-Kill Rate: ₹${perKillRate.toStringAsFixed(0)} (Auto-Calculates Kill Prize)",
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: StreamBuilder<List<RegistrationModel>>(
              stream: tournamentProvider.participants(widget.tournament.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                final participants = snapshot.data ?? [];
                
                // Initialize results list if empty
                if (_results.isEmpty) {
                  for (var p in participants) {
                    _results.add({
                      'userId': p.userId,
                      'playerName': p.userName,
                      'ffUid': p.ffUid,
                      'rank': 0,
                      'kills': 0,
                      'positionPrize': 0.0,
                      'killPrize': 0.0,
                      'booyahPrize': 0.0,
                      'prizeWon': 0.0,
                    });
                  }
                }

                if (_results.isEmpty) {
                  return const Center(
                    child: Text("No participants found to upload results.", style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final res = _results[index];
                    final userId = res['userId'] as String? ?? '';
                    final participant = participants.firstWhere(
                      (p) => p.userId == userId,
                      orElse: () => RegistrationModel(
                        id: '',
                        tournamentId: widget.tournament.id,
                        userId: userId,
                        userName: res['playerName'] ?? 'Player',
                        ffUid: res['ffUid'] ?? '',
                        userPhone: '',
                        slotNumber: index + 1,
                        status: 'joined',
                        joinedAt: DateTime.now(),
                      ),
                    );

                    final profilePic = participant.userProfilePic;
                    final slotNum = participant.slotNumber;

                    return Card(
                      color: AppColors.surface,
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundImage: (profilePic != null && profilePic.isNotEmpty)
                                      ? NetworkImage(profilePic)
                                      : null,
                                  child: (profilePic == null || profilePic.isEmpty)
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${res['playerName']} • Slot $slotNum",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      Text("UID: ${res['ffUid']}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                // Quick "🏆 SET BOOYAH" Button
                                InkWell(
                                  onTap: () {
                                    _setRank(res, "1");
                                    _controllerFor(res['userId'], 'rank').text = "1";
                                  },
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: (res['rank'] == 1)
                                          ? AppColors.primary
                                          : AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppColors.primary),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.emoji_events,
                                          size: 14,
                                          color: (res['rank'] == 1) ? Colors.black : AppColors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          (res['rank'] == 1) ? "BOOYAH! #1" : "SET BOOYAH",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: (res['rank'] == 1) ? Colors.black : AppColors.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white10),
                            
                            // Fields row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInputField(
                                    "Rank",
                                    TextInputType.number,
                                    _controllerFor(res['userId'], 'rank'),
                                    (val) => _setRank(res, val),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Kills with Quick Increment / Decrement
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildInputField(
                                              "Kills",
                                              TextInputType.number,
                                              _controllerFor(res['userId'], 'kills'),
                                              (val) => _setKills(res, val, perKillRate),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                                            onPressed: () {
                                              final currentKills = (res['kills'] as int? ?? 0);
                                              if (currentKills > 0) {
                                                final newKills = currentKills - 1;
                                                _controllerFor(res['userId'], 'kills').text = "$newKills";
                                                _setKills(res, "$newKills", perKillRate);
                                              }
                                            },
                                          ),
                                          IconButton(
                                            visualDensity: VisualDensity.compact,
                                            icon: const Icon(Icons.add_circle_outline, color: AppColors.neonGreen, size: 20),
                                            onPressed: () {
                                              final currentKills = (res['kills'] as int? ?? 0);
                                              final newKills = currentKills + 1;
                                              _controllerFor(res['userId'], 'kills').text = "$newKills";
                                              _setKills(res, "$newKills", perKillRate);
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildInputField(
                                    "Position Prize (₹)",
                                    TextInputType.number,
                                    _controllerFor(res['userId'], 'positionPrize'),
                                    (val) => _setPrize(res, 'positionPrize', val),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInputField(
                                    "Kill Prize (₹)",
                                    TextInputType.number,
                                    _controllerFor(res['userId'], 'killPrize'),
                                    (val) => _setPrize(res, 'killPrize', val),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _buildInputField(
                                    "Booyah Prize (₹)",
                                    TextInputType.number,
                                    _controllerFor(res['userId'], 'booyahPrize'),
                                    (val) => _setPrize(res, 'booyahPrize', val),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ValueListenableBuilder<double>(
                              valueListenable: _totalNotifierFor(res['userId']),
                              builder: (context, total, _) => Text(
                                "Total coins: ₹${total.toStringAsFixed(0)}",
                                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(String label, TextInputType type, TextEditingController controller, Function(String) onChanged) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
      ),
      onChanged: onChanged,
    );
  }

  void _setRank(Map<String, dynamic> result, String value) {
    final rank = int.tryParse(value) ?? 0;
    result['rank'] = rank;

    // Auto-fill Booyah Prize if Rank 1 is entered and tournament has a Booyah Pool or Prize Pool
    if (rank == 1) {
      final defaultBooyah = widget.tournament.booyahPool > 0
          ? widget.tournament.booyahPool
          : widget.tournament.prizePool;

      if (defaultBooyah > 0) {
        result['booyahPrize'] = defaultBooyah;
        _controllerFor(result['userId'], 'booyahPrize').text = defaultBooyah.toStringAsFixed(0);
      }
    }

    _refreshTotal(result);
    setState(() {});
  }

  void _setPrize(Map<String, dynamic> result, String key, String value) {
    result[key] = double.tryParse(value) ?? 0.0;
    final total = ((result['positionPrize'] as num?)?.toDouble() ?? 0.0) +
        ((result['killPrize'] as num?)?.toDouble() ?? 0.0) +
        ((result['booyahPrize'] as num?)?.toDouble() ?? 0.0);
    result['prizeWon'] = total;
    _totalNotifierFor(result['userId']).value = total;
  }

  void _setKills(Map<String, dynamic> result, String value, double perKillRate) {
    final kills = int.tryParse(value) ?? 0;
    result['kills'] = kills;
    final autoKillPrize = kills * perKillRate;
    result['killPrize'] = autoKillPrize;
    _controllerFor(result['userId'], 'killPrize').text = autoKillPrize > 0 ? autoKillPrize.toStringAsFixed(0) : '0';
    _refreshTotal(result);
    setState(() {});
  }

  void _refreshTotal(Map<String, dynamic> result) {
    final total = (result['positionPrize'] as double) +
        (result['killPrize'] as double) +
        (result['booyahPrize'] as double);
    result['prizeWon'] = total;
    _totalNotifierFor(result['userId']).value = total;
  }

  Future<void> _submitResults() async {
    setState(() => _isLoading = true);
    try {
      // Sort results by rank before submitting so Rank 1 comes first, Rank 2 second, etc.
      _results.sort((a, b) {
        final rA = (a['rank'] as num?)?.toInt() ?? 0;
        final rB = (b['rank'] as num?)?.toInt() ?? 0;
        if (rA == 0 && rB == 0) return 0;
        if (rA == 0) return 1;
        if (rB == 0) return -1;
        return rA.compareTo(rB);
      });

      await Provider.of<TournamentProvider>(context, listen: false)
          .uploadResultsAndComplete(widget.tournament.id, _results);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Results uploaded successfully!")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
