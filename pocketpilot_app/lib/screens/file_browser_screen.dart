import 'package:flutter/material.dart';
import '../services/pocketpilot_service.dart';
import 'dart:convert';

class FileBrowserScreen extends StatefulWidget {
  final PocketPilotService service;

  const FileBrowserScreen({super.key, required this.service});

  @override
  State<FileBrowserScreen> createState() => _FileBrowserScreenState();
}

class _FileBrowserScreenState extends State<FileBrowserScreen> {
  PocketPilotService get _service => widget.service;
  List<dynamic> _entries = [];
  String _currentPath = '.';
  String? _parentPath;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _navigateTo('.');
  }

  Future<void> _navigateTo(String path) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _service.listFiles(path: path);
    if (!mounted) return;

    if (result != null && result['status'] == 'ok') {
      setState(() {
        _entries = result['entries'] as List<dynamic>;
        _currentPath = result['path'] as String;
        _parentPath = result['parent'] as String?;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result?['message'] as String? ?? 'Failed to list files';
        _isLoading = false;
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  IconData _iconForEntry(Map<String, dynamic> entry) {
    if (entry['is_dir'] == true) return Icons.folder;
    final name = (entry['name'] as String).toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') ||
        name.endsWith('.gif') || name.endsWith('.bmp')) return Icons.image;
    if (name.endsWith('.mp4') || name.endsWith('.mkv') || name.endsWith('.avi') ||
        name.endsWith('.mov')) return Icons.movie;
    if (name.endsWith('.mp3') || name.endsWith('.wav') || name.endsWith('.flac')) return Icons.music_note;
    if (name.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (name.endsWith('.zip') || name.endsWith('.rar') || name.endsWith('.tar') ||
        name.endsWith('.gz')) return Icons.archive;
    if (name.endsWith('.exe') || name.endsWith('.msi') || name.endsWith('.app')) return Icons.settings;
    if (name.endsWith('.py') || name.endsWith('.dart') || name.endsWith('.js') ||
        name.endsWith('.ts') || name.endsWith('.java') || name.endsWith('.c') ||
        name.endsWith('.cpp')) return Icons.code;
    if (name.endsWith('.txt') || name.endsWith('.md') || name.endsWith('.csv')) return Icons.description;
    return Icons.insert_drive_file;
  }

  Color _colorForEntry(Map<String, dynamic> entry) {
    if (entry['is_dir'] == true) return const Color(0xFF0F3460);
    final name = (entry['name'] as String).toLowerCase();
    if (name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') ||
        name.endsWith('.gif')) return Colors.purple;
    if (name.endsWith('.mp4') || name.endsWith('.mkv')) return Colors.red;
    if (name.endsWith('.mp3') || name.endsWith('.wav')) return Colors.teal;
    if (name.endsWith('.pdf')) return Colors.red;
    if (name.endsWith('.zip') || name.endsWith('.rar')) return Colors.orange;
    if (name.endsWith('.exe')) return Colors.blueGrey;
    if (name.endsWith('.py') || name.endsWith('.dart') || name.endsWith('.js')) return Colors.green;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Browser'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _navigateTo(_currentPath),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Current path bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF0F3460),
            child: Row(
              children: [
                Icon(Icons.folder_open, color: Colors.grey[400], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentPath,
                    style: TextStyle(color: Colors.grey[300], fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // File list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFE94560)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text(_error!, style: TextStyle(color: Colors.grey[500])),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _navigateTo('.'),
                              child: const Text('Go to Root'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _navigateTo(_currentPath),
                        child: ListView.builder(
                          itemCount: _entries.length + (_parentPath != null ? 1 : 0),
                          itemBuilder: (ctx, index) {
                            // Parent directory entry
                            if (_parentPath != null && index == 0) {
                              return _buildParentTile();
                            }
                            final entryIndex = _parentPath != null ? index - 1 : index;
                            return _buildFileTile(_entries[entryIndex] as Map<String, dynamic>);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentTile() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _navigateTo(_parentPath!),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade800)),
          ),
          child: Row(
            children: [
              const Icon(Icons.folder, color: Color(0xFFE94560), size: 24),
              const SizedBox(width: 16),
              Text('.. (parent directory)', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileTile(Map<String, dynamic> entry) {
    final isDir = entry['is_dir'] == true;
    final name = entry['name'] as String? ?? 'unknown';
    final size = entry['size'] as int? ?? 0;
    final modified = entry['modified'] as String?;
    final iconColor = _colorForEntry(entry);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDir ? () => _navigateTo(entry['path'] as String) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade800)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _iconForEntry(entry),
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (!isDir && size > 0) ...[
                          Text(_formatSize(size), style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                          const SizedBox(width: 8),
                        ],
                        if (modified != null)
                          Text(_formatDate(modified), style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              if (isDir)
                Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}