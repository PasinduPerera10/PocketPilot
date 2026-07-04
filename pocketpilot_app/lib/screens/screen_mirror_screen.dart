import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/pocketpilot_service.dart';

class ScreenMirrorScreen extends StatefulWidget {
  final PocketPilotService service;

  const ScreenMirrorScreen({super.key, required this.service});

  @override
  State<ScreenMirrorScreen> createState() => _ScreenMirrorScreenState();
}

class _ScreenMirrorScreenState extends State<ScreenMirrorScreen> {
  PocketPilotService get _service => widget.service;
  Uint8List? _currentScreenshot;
  Timer? _screenshotTimer;
  bool _isMirroring = false;
  bool _isLoading = false;
  int _refreshIntervalMs = 2000; // 2 seconds default

  @override
  void dispose() {
    _stopMirroring();
    super.dispose();
  }

  void _startMirroring() {
    setState(() => _isMirroring = true);
    _fetchScreenshot();
    _screenshotTimer = Timer.periodic(
      Duration(milliseconds: _refreshIntervalMs),
      (_) => _fetchScreenshot(),
    );
  }

  void _stopMirroring() {
    _isMirroring = false;
    _screenshotTimer?.cancel();
    _screenshotTimer = null;
  }

  Future<void> _fetchScreenshot() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final bytes = await _service.getScreenshot();
    if (!mounted) return;

    if (bytes != null) {
      setState(() {
        _currentScreenshot = bytes;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (_isMirroring) {
        _stopMirroring();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection lost. Mirroring stopped.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _changeInterval(int ms) {
    setState(() => _refreshIntervalMs = ms);
    if (_isMirroring) {
      _stopMirroring();
      _startMirroring();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Mirror'),
        actions: [
          if (_isMirroring)
            PopupMenuButton<int>(
              onSelected: _changeInterval,
              icon: const Icon(Icons.speed),
              tooltip: 'Refresh rate',
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 500, child: Text('0.5s (fast)')),
                const PopupMenuItem(value: 1000, child: Text('1s')),
                const PopupMenuItem(value: 2000, child: Text('2s (default)')),
                const PopupMenuItem(value: 3000, child: Text('3s')),
                const PopupMenuItem(value: 5000, child: Text('5s (slow)')),
              ],
            ),
          IconButton(
            icon: Icon(_isMirroring ? Icons.stop : Icons.play_arrow),
            onPressed: _isMirroring ? _stopMirroring : _startMirroring,
            tooltip: _isMirroring ? 'Stop Mirroring' : 'Start Mirroring',
          ),
        ],
      ),
      body: Center(
        child: _currentScreenshot == null
            ? _buildPlaceholder()
            : _buildMirrorView(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.tv, size: 80, color: Colors.grey[700]),
        const SizedBox(height: 16),
        Text(
          'Screen Mirror',
          style: TextStyle(fontSize: 20, color: Colors.grey[500], fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap play to start mirroring\nScreenshots refresh every ${_refreshIntervalMs ~/ 1000}s',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _startMirroring,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Start Mirroring'),
        ),
      ],
    );
  }

  Widget _buildMirrorView() {
    return Column(
      children: [
        // Status bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF0F3460),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Live - ${_refreshIntervalMs ~/ 1000}s interval',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
              const Spacer(),
              if (_isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
            ],
          ),
        ),

        // Screenshot image
        Expanded(
          child: GestureDetector(
            onTap: _fetchScreenshot,
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: Center(
                child: _currentScreenshot != null
                    ? Image.memory(
                        _currentScreenshot!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        errorBuilder: (ctx, error, stack) => Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.broken_image, size: 48, color: Colors.red),
                            const SizedBox(height: 8),
                            Text('Failed to load screenshot', style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),

        // Bottom controls
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF0F3460),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _fetchScreenshot,
                tooltip: 'Refresh now',
              ),
              const SizedBox(width: 16),
              Text(
                'Tap image to refresh',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}