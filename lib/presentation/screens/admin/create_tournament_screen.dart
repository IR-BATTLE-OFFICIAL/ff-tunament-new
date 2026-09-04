import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:ff_arena/core/utils/storage_service.dart';
import 'package:ff_arena/data/models/tournament_model.dart';
import 'package:ff_arena/data/models/game_mode_model.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class CreateTournamentScreen extends StatefulWidget {
  final TournamentModel? tournament;

  const CreateTournamentScreen({super.key, this.tournament});

  @override
  State<CreateTournamentScreen> createState() => _CreateTournamentScreenState();
}

class _CreateTournamentScreenState extends State<CreateTournamentScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final _titleController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _entryFeeController = TextEditingController();
  final _prizePoolController = TextEditingController();
  final _booyahPoolController = TextEditingController();
  final _perKillController = TextEditingController();
  final _totalSlotsController = TextEditingController();
  final _rulesController = TextEditingController();
  final _liveStreamUrlController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _imageUrlController.dispose();
    _entryFeeController.dispose();
    _prizePoolController.dispose();
    _booyahPoolController.dispose();
    _perKillController.dispose();
    _totalSlotsController.dispose();
    _rulesController.dispose();
    _liveStreamUrlController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final tournament = widget.tournament;
    if (tournament == null) {
      _loadDefaultRules();
      return;
    }

    _titleController.text = tournament.title;
    _imageUrlController.text = tournament.imageUrl;
    _entryFeeController.text = tournament.entryFee.toStringAsFixed(0);
    _prizePoolController.text = tournament.prizePool.toStringAsFixed(0);
    _booyahPoolController.text = tournament.booyahPool > 0 ? tournament.booyahPool.toStringAsFixed(0) : '';
    _perKillController.text = tournament.perKillPrize.toStringAsFixed(0);
    _totalSlotsController.text = tournament.totalSlots.toString();
    _rulesController.text = tournament.rules;
    _liveStreamUrlController.text = tournament.liveStreamUrl ?? '';
    _selectedDate = tournament.dateTime;
    _isMega = tournament.isMega;
    _isFree = tournament.isFree;
    _matchType = tournament.matchType;
    _mode = tournament.mode;
    _gameModeId = tournament.gameModeId;
    _map = tournament.map;
    _version = tournament.version;
    final savedPlatform = tournament.platform ?? 'YouTube';
    _platform = ['YouTube', 'Rooter', 'Loco', 'Other'].contains(savedPlatform) ? savedPlatform : 'Other';
  }

  Future<void> _loadDefaultRules() async {
    final provider = Provider.of<TournamentProvider>(context, listen: false);
    final config = await provider.appConfig().first;
    if (config.containsKey('defaultRules')) {
      setState(() {
        _rulesController.text = config['defaultRules'];
      });
    }
  }

  File? _imageFile;
  bool _isUploading = false;
  bool _isMega = false;
  bool _isFree = false;
  String _matchType = 'Solo';
  String _mode = '';
  String? _gameModeId;
  String _map = 'Bermuda';
  String _version = 'Mobile';
  String _platform = 'YouTube';
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
      firstDate: today,
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFFFD700),
              onPrimary: Colors.black,
              surface: Color(0xFF1B1F24),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );
      
      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      _uploadImage();
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null) return;

    setState(() => _isUploading = true);
    try {
      final storageService = StorageService();
      final url = await storageService.uploadImage('tournaments', _imageFile!);
      
      if (url != null) {
        setState(() {
          _imageUrlController.text = url;
          _isUploading = false;
        });
      }
    } catch (e) {
      setState(() => _isUploading = false);
      String errorMsg = e.toString();
      if (errorMsg.contains('object-not-found')) {
        errorMsg = "Storage Error: Bucket mismatch or propagation lag. Please try again in a few seconds.";
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errorMsg),
        backgroundColor: Colors.redAccent,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.tournament == null ? "Create Tournament" : "Edit Tournament")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle("General Information"),
              const SizedBox(height: 10),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Tournament Title",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) => v!.trim().isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _totalSlotsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Total Slots",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.groups),
                ),
                validator: (v) => int.tryParse(v!.trim()) == null ? "Enter valid slots" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _entryFeeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: "Entry Fee (₹)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.confirmation_number),
                ),
                validator: (v) => double.tryParse(v!.trim()) == null ? "Enter valid amount" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _prizePoolController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: "Prize Pool (₹)",
                  hintText: "Enter total prize pool",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.emoji_events),
                ),
                validator: (v) => double.tryParse(v!.trim()) == null ? "Enter valid amount" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _booyahPoolController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: "Booyah Pool (₹) (Optional)",
                  hintText: "Enter Booyah winner prize",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.military_tech),
                ),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _perKillController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: "Per Kill Prize (₹)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.gps_fixed),
                ),
                validator: (v) => double.tryParse(v!.trim()) == null ? "Enter valid amount" : null,
              ),
              const SizedBox(height: 25),
              
              // Image Picker Section
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                    image: _imageFile != null ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover) : null,
                  ),
                  child: _imageFile == null 
                    ? const Center(child: Text("Upload Banner"))
                    : null,
                ),
              ),
              const SizedBox(height: 15),

              // Date/Time Picker
              InkWell(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.grey),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat('yyyy-MM-dd hh:mm a').format(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),
              _buildSectionTitle("Match Configuration"),

              const SizedBox(height: 10),
              StreamBuilder<List<GameModeModel>>(
                stream: Provider.of<TournamentProvider>(context, listen: false).gameModes(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const SizedBox(
                      height: 50,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }

                  final modesList = (snapshot.data ?? [])
                      .where(
                        (mode) =>
                            mode.title.trim().isNotEmpty &&
                            (mode.isActive ||
                                mode.id == _gameModeId ||
                                mode.title.trim().toLowerCase() == _mode.trim().toLowerCase()),
                      )
                      .toList();

                  if (modesList.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "No active Game Modes found! Please add and activate a mode in Admin Panel -> Manage Game Modes first.",
                              style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final selectedModeById = modesList.where((mode) => mode.id == _gameModeId);
                  final selectedModeByTitle = modesList.where(
                    (mode) => mode.title.trim().toLowerCase() == _mode.trim().toLowerCase(),
                  );
                  final selectedMode = selectedModeById.isNotEmpty
                      ? selectedModeById.first
                      : selectedModeByTitle.isNotEmpty
                          ? selectedModeByTitle.first
                          : modesList.first;
                  _gameModeId = selectedMode.id;
                  _mode = selectedMode.title.trim();

                  return DropdownButtonFormField<String>(
                    value: selectedMode.id,
                    items: modesList
                        .map((mode) => DropdownMenuItem(value: mode.id, child: Text(mode.title.trim())))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      final mode = modesList.firstWhere((item) => item.id == v);
                      setState(() {
                        _gameModeId = mode.id;
                        _mode = mode.title.trim();
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: "Tournament Mode",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.sports_esports),
                    ),
                  );
                },
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _matchType,
                items: ['Solo', 'Duo', 'Squad'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _matchType = v!),
                decoration: const InputDecoration(
                  labelText: "Match Type",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _map,
                items: ['Bermuda', 'Purgatory', 'Kalahari', 'Nextierra', 'Iron Cage'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _map = v!),
                decoration: const InputDecoration(
                  labelText: "Map",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.map),
                ),
              ),
              const SizedBox(height: 25),
              _buildSectionTitle("Streaming & Extra"),
              const SizedBox(height: 10),
              TextFormField(
                controller: _liveStreamUrlController,
                decoration: const InputDecoration(
                  labelText: "Live Stream URL (Optional)",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.live_tv),
                ),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _platform,
                items: ['YouTube', 'Rooter', 'Loco', 'Other'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _platform = v!),
                decoration: const InputDecoration(
                  labelText: "Platform",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.videocam),
                ),
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text("Mega Tournament", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("Special highlighting on home screen"),
                value: _isMega, 
                onChanged: (v) => setState(() => _isMega = v),
                secondary: const Icon(Icons.stars, color: Colors.amber),
                tileColor: Colors.white10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 15),
              SwitchListTile(
                title: const Text("FREE Tournament", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                subtitle: const Text("No entry fee — anyone can join for free!"),
                value: _isFree,
                onChanged: (v) {
                  setState(() {
                    _isFree = v;
                    if (v) {
                      _entryFeeController.text = '0';
                    } else {
                      _entryFeeController.clear();
                    }
                  });
                },
                secondary: const Icon(Icons.card_giftcard, color: Colors.green),
                tileColor: Colors.green.withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _rulesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Rules",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.rule),
                ),
                validator: (v) => v!.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveTournament,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading 
                    ? const SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                      )
                    : Text(
                        widget.tournament == null ? "CREATE TOURNAMENT" : "UPDATE TOURNAMENT",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.blueGrey,
      ),
    );
  }

  void _saveTournament() async {
    if (_isLoading) return;
    if (_formKey.currentState!.validate()) {
      if (_gameModeId == null || _mode.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please select an active tournament mode."),
          backgroundColor: Colors.redAccent,
        ));
        return;
      }

      double entryFee = _isFree ? 0.0 : (double.tryParse(_entryFeeController.text) ?? 0.0);
      double prizePool = double.tryParse(_prizePoolController.text) ?? 0.0;
      double booyahPool = double.tryParse(_booyahPoolController.text) ?? 0.0;
      double perKillPrize = double.tryParse(_perKillController.text) ?? 0.0;

      if (!_isFree && prizePool == 0.0 && perKillPrize == 0.0 && booyahPool == 0.0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please provide Prize Pool, Booyah Pool, or Per Kill Prize."),
          backgroundColor: Colors.redAccent,
        ));
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final tournament = TournamentModel(
          id: widget.tournament?.id ?? '',
          title: _titleController.text,
          imageUrl: _imageUrlController.text,
          dateTime: _selectedDate,
          entryFee: entryFee,
          prizePool: prizePool,
          booyahPool: booyahPool,
          perKillPrize: perKillPrize,
          matchType: _matchType,
          mode: _mode,
          gameModeId: _gameModeId,
          map: _map,
          totalSlots: int.parse(_totalSlotsController.text),
          filledSlots: widget.tournament?.filledSlots ?? 0,
          version: _version,
          status: widget.tournament?.status ?? 'upcoming',
          roomId: widget.tournament?.roomId,
          roomPassword: widget.tournament?.roomPassword,
          rules: _rulesController.text,
          isMega: _isMega,
          isFree: _isFree,
          liveStreamUrl: _liveStreamUrlController.text.isEmpty ? null : _liveStreamUrlController.text,
          platform: _platform,
          winnerId: widget.tournament?.winnerId,
          winnerName: widget.tournament?.winnerName,
          resultImageUrl: widget.tournament?.resultImageUrl,
        );

        final provider = Provider.of<TournamentProvider>(context, listen: false);
        if (widget.tournament == null) {
          await provider.createTournament(tournament);
        } else {
          await provider.updateTournament(tournament.id, tournament.toMap());
        }
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.redAccent,
          ));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
}
