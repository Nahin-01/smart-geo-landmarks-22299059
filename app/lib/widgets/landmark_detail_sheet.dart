import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/landmark.dart';
import '../providers/app_state.dart';
import 'score_color.dart';

Future<void> showLandmarkDetailSheet(BuildContext context, Landmark landmark) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => LandmarkDetailSheet(landmark: landmark),
  );
}

class LandmarkDetailSheet extends StatefulWidget {
  final Landmark landmark;
  const LandmarkDetailSheet({super.key, required this.landmark});

  @override
  State<LandmarkDetailSheet> createState() => _LandmarkDetailSheetState();
}

class _LandmarkDetailSheetState extends State<LandmarkDetailSheet> {
  bool _visiting = false;

  Future<void> _visit() async {
    setState(() => _visiting = true);
    final app = context.read<AppState>();
    try {
      final message = await app.visitLandmark(widget.landmark);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Visit failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _visiting = false);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.landmark;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (l.image != null && l.image!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: l.image!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (c, u, e) => Container(
                  height: 180,
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported, size: 40),
                ),
                placeholder: (c, u) => Container(
                  height: 180,
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(l.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Chip(
                avatar: CircleAvatar(backgroundColor: colorForScore(l.score), radius: 6),
                label: Text('Score: ${l.score.toStringAsFixed(1)}'),
              ),
              Chip(label: Text('Visits: ${l.visitCount}')),
              if (l.avgDistance != null)
                Chip(label: Text('Avg distance: ${l.avgDistance!.toStringAsFixed(1)} m')),
            ],
          ),
          const SizedBox(height: 4),
          Text('Lat: ${l.lat.toStringAsFixed(5)}, Lon: ${l.lon.toStringAsFixed(5)}',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _visiting ? null : _visit,
              icon: _visiting
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.directions_walk),
              label: Text(_visiting ? 'Getting location...' : 'Visit this landmark'),
            ),
          ),
        ],
      ),
    );
  }
}
