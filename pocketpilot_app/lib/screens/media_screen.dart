import 'package:flutter/material.dart';
import '../services/pocketpilot_service.dart';

class MediaScreen extends StatefulWidget {
  final PocketPilotService service;

  const MediaScreen({super.key, required this.service});

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  PocketPilotService get _service => widget.service;

  Future<void> _execute(String action, Future<bool> Function() command) async {
    final success = await command();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '$action' : 'Failed: $action'),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.music_note, size: 22),
            SizedBox(width: 8),
            Text('Media Controls'),
          ],
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Album art placeholder
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE94560).withOpacity(0.3)),
              ),
              child: const Icon(Icons.music_note, size: 80, color: Color(0xFFE94560)),
            ),
            const SizedBox(height: 48),

            // Media control buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMediaButton(
                  Icons.skip_previous,
                  'Previous',
                  () => _execute('Previous Track', _service.mediaPrev),
                ),
                const SizedBox(width: 24),
                _buildMediaButton(
                  Icons.play_arrow,
                  'Play/Pause',
                  () => _execute('Play/Pause', _service.mediaPlayPause),
                  size: 72,
                ),
                const SizedBox(width: 24),
                _buildMediaButton(
                  Icons.skip_next,
                  'Next',
                  () => _execute('Next Track', _service.mediaNext),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Label
            Text('Control music and video playback',
                style: TextStyle(color: Colors.grey[500], fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaButton(IconData icon, String label, VoidCallback onTap, {double size = 64}) {
    return Column(
      children: [
        Material(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(size / 2),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(size / 2),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE94560).withOpacity(0.3)),
              ),
              child: Icon(icon, color: const Color(0xFFE94560), size: size * 0.5),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      ],
    );
  }
}