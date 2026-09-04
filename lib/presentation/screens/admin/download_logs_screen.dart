import 'package:flutter/material.dart';
import 'package:ff_arena/core/theme/app_theme.dart';
import 'package:ff_arena/data/models/download_log_model.dart';
import 'package:ff_arena/presentation/providers/tournament_provider.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DownloadLogsScreen extends StatelessWidget {
  const DownloadLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TournamentProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Website Download Logs")),
      body: StreamBuilder<List<DownloadLog>>(
        stream: provider.downloadLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final logs = snapshot.data ?? [];

          if (logs.isEmpty) {
            return const Center(child: Text("No download logs found."));
          }

          return ListView.builder(
            itemCount: logs.length,
            padding: const EdgeInsets.all(10),
            itemBuilder: (context, index) {
              final log = logs[index];
              final date = DateFormat('dd MMM yyyy, hh:mm a').format(log.timestamp);

              return Card(
                color: AppColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.download, color: Colors.white),
                  ),
                  title: Text("Architecture: ${log.architecture.toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Time: $date", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text("Platform: ${log.platform}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text("User Agent: ${log.userAgent}", style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
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
}
