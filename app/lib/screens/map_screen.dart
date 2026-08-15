import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/score_color.dart';
import '../widgets/landmark_detail_sheet.dart';

// Roughly the geographic center of Bangladesh.
const LatLng kBangladeshCenter = LatLng(23.685, 90.3563);

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final landmarks = app.landmarks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Landmarks Map'),
        actions: [
          if (!app.isOnline)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Chip(
                avatar: Icon(Icons.cloud_off, size: 16),
                label: Text('Offline'),
                visualDensity: VisualDensity.compact,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong),
            tooltip: 'Recenter on Bangladesh',
            onPressed: () => _mapController.move(kBangladeshCenter, 7),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: app.isLoading ? null : app.refreshFromServer,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: kBangladeshCenter,
              initialZoom: 7,
              minZoom: 4,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.cse489.smart_landmarks',
              ),
              MarkerLayer(
                markers: landmarks
                    .map(
                      (l) => Marker(
                        point: LatLng(l.lat, l.lon),
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () => showLandmarkDetailSheet(context, l),
                          child: Tooltip(
                            message: l.title,
                            child: Icon(
                              Icons.location_on,
                              size: 40,
                              color: colorForScore(l.score),
                              shadows: const [
                                Shadow(color: Colors.black45, blurRadius: 4)
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          if (app.isLoading)
            const Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(child: LinearProgressIndicator()),
            ),
          Positioned(
            left: 12,
            bottom: 12,
            child: _Legend(),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Low', style: TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
            Container(
              width: 60,
              height: 8,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.red, Colors.amber, Colors.green],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 4),
            const Text('High', style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
