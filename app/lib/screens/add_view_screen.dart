import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/app_state.dart';
import '../services/location_service.dart';
import '../models/landmark.dart';

class AddViewScreen extends StatefulWidget {
  const AddViewScreen({super.key});

  @override
  State<AddViewScreen> createState() => _AddViewScreenState();
}

class _AddViewScreenState extends State<AddViewScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add / View'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Add New', icon: Icon(Icons.add_location_alt)),
            Tab(text: 'Manage', icon: Icon(Icons.list_alt)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_AddLandmarkForm(), _ManageLandmarksList()],
      ),
    );
  }
}

class _AddLandmarkForm extends StatefulWidget {
  const _AddLandmarkForm();

  @override
  State<_AddLandmarkForm> createState() => _AddLandmarkFormState();
}

class _AddLandmarkFormState extends State<_AddLandmarkForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final LocationService _locationService = LocationService();
  final ImagePicker _picker = ImagePicker();

  File? _imageFile;
  bool _fetchingLocation = false;
  bool _submitting = false;

  Future<void> _autoFetchLocation() async {
    setState(() => _fetchingLocation = true);
    try {
      final pos = await _locationService.getCurrentLocation();
      _latController.text = pos.latitude.toStringAsFixed(6);
      _lonController.text = pos.longitude.toStringAsFixed(6);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not get GPS location: $e')));
    } finally {
      if (mounted) setState(() => _fetchingLocation = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await context.read<AppState>().addLandmark(
            title: _titleController.text.trim(),
            lat: double.parse(_latController.text.trim()),
            lon: double.parse(_lonController.text.trim()),
            image: _imageFile,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Landmark created successfully.')));
      _titleController.clear();
      _latController.clear();
      _lonController.clear();
      setState(() => _imageFile = null);
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Could not create landmark'),
          content: Text(e.toString()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final online = context.watch<AppState>().isOnline;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!online)
              Card(
                color: Colors.orange[50],
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'You are offline. Creating a landmark requires a live connection to the '
                    'faculty API, so this action is disabled until you are back online.',
                  ),
                ),
              ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration:
                        const InputDecoration(labelText: 'Latitude', border: OutlineInputBorder()),
                    validator: (v) =>
                        (v == null || double.tryParse(v) == null) ? 'Invalid' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _lonController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration:
                        const InputDecoration(labelText: 'Longitude', border: OutlineInputBorder()),
                    validator: (v) =>
                        (v == null || double.tryParse(v) == null) ? 'Invalid' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _fetchingLocation ? null : _autoFetchLocation,
              icon: _fetchingLocation
                  ? const SizedBox(
                      width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location),
              label: Text(_fetchingLocation ? 'Fetching GPS...' : 'Auto-fetch current GPS location'),
            ),
            const SizedBox(height: 16),
            if (_imageFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(_imageFile!, height: 160, fit: BoxFit.cover),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: Text(_imageFile == null ? 'Pick an image' : 'Change image'),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: (_submitting || !online) ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: Text(_submitting ? 'Submitting...' : 'Create Landmark'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageLandmarksList extends StatelessWidget {
  const _ManageLandmarksList();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final all = app.allLandmarksIncludingDeleted;

    if (all.isEmpty) {
      return const Center(child: Text('No landmarks to manage yet.'));
    }

    return ListView.builder(
      itemCount: all.length,
      itemBuilder: (context, index) {
        final Landmark l = all[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: l.image != null && l.image!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: l.image!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget: (c, u, e) => Container(width: 48, height: 48, color: Colors.grey[200]),
                  )
                : Container(width: 48, height: 48, color: Colors.grey[200]),
          ),
          title: Text(
            l.title,
            style: l.isDeleted
                ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)
                : null,
          ),
          subtitle: Text(l.isDeleted ? 'Deleted' : 'Score: ${l.score.toStringAsFixed(1)}'),
          trailing: l.isDeleted
              ? TextButton(
                  onPressed: () => context.read<AppState>().restoreLandmark(l),
                  child: const Text('Restore'),
                )
              : IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => context.read<AppState>().deleteLandmark(l),
                ),
        );
      },
    );
  }
}
