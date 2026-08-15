import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/score_color.dart';
import '../widgets/landmark_detail_sheet.dart';

class LandmarksScreen extends StatelessWidget {
  const LandmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final list = app.filteredSortedLandmarks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Landmarks'),
        actions: [
          if (!app.isOnline)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.cloud_off),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Text('Sort:'),
                const SizedBox(width: 8),
                DropdownButton<SortMode>(
                  value: app.sortMode,
                  items: const [
                    DropdownMenuItem(
                      value: SortMode.scoreHighToLow,
                      child: Text('Score: High to Low'),
                    ),
                    DropdownMenuItem(
                      value: SortMode.scoreLowToHigh,
                      child: Text('Score: Low to High'),
                    ),
                  ],
                  onChanged: (mode) {
                    if (mode != null) app.setSortMode(mode);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text('Min score: ${app.minScoreFilter.toStringAsFixed(0)}'),
                Expanded(
                  child: Slider(
                    value: app.minScoreFilter,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: app.minScoreFilter.toStringAsFixed(0),
                    onChanged: app.setMinScoreFilter,
                  ),
                ),
              ],
            ),
          ),
          if (app.isLoading) const LinearProgressIndicator(),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('No landmarks match this filter.'))
                : RefreshIndicator(
                    onRefresh: app.refreshFromServer,
                    child: ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final l = list[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          child: ListTile(
                            onTap: () => showLandmarkDetailSheet(context, l),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: l.image != null && l.image!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: l.image!,
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                      errorWidget: (c, u, e) => Container(
                                        width: 56,
                                        height: 56,
                                        color: Colors.grey[200],
                                        child: const Icon(Icons.image_not_supported),
                                      ),
                                    )
                                  : Container(
                                      width: 56,
                                      height: 56,
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.landscape),
                                    ),
                            ),
                            title: Text(l.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${l.visitCount} visits'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: colorForScore(l.score).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: colorForScore(l.score)),
                              ),
                              child: Text(
                                l.score.toStringAsFixed(1),
                                style: TextStyle(
                                  color: colorForScore(l.score),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
