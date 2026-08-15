import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final history = app.visitHistory;
    final dateFormat = DateFormat('MMM d, y  h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visit Activity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync now',
            onPressed: () async {
              await app.syncNow();
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Synced.')));
              }
            },
          ),
        ],
      ),
      body: history.isEmpty
          ? const Center(child: Text('No visits yet. Go visit a landmark!'))
          : RefreshIndicator(
              onRefresh: app.syncNow,
              child: ListView.separated(
                itemCount: history.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final v = history[index];
                  return ListTile(
                    leading: _statusIcon(v.status),
                    title: Text(v.landmarkTitle),
                    subtitle: Text(dateFormat.format(v.visitTime)),
                    trailing: Text(
                      v.status == 'pending'
                          ? 'Pending...'
                          : v.status == 'failed'
                              ? 'Failed'
                              : '${v.distance?.toStringAsFixed(1) ?? '-'} m',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: v.status == 'pending'
                            ? Colors.orange
                            : v.status == 'failed'
                                ? Colors.red
                                : Colors.green[700],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _statusIcon(String status) {
    switch (status) {
      case 'done':
        return const CircleAvatar(child: Icon(Icons.check));
      case 'pending':
        return const CircleAvatar(child: Icon(Icons.hourglass_top));
      default:
        return const CircleAvatar(child: Icon(Icons.error_outline));
    }
  }
}
