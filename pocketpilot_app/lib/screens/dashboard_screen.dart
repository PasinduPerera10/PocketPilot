import 'dart:async';
import 'package:flutter/material.dart';
import '../services/pocketpilot_service.dart';
import 'pairing_screen.dart';
import 'trackpad_screen.dart';
import 'keyboard_screen.dart';
import 'power_screen.dart';
import 'screen_mirror_screen.dart';
import 'file_browser_screen.dart';
import 'media_screen.dart';
import 'app_launcher_screen.dart';
import 'volume_screen.dart';
import 'laptop_settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  final PocketPilotService service;

  const DashboardScreen({super.key, required this.service});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  PocketPilotService get _service => widget.service;

  Map<String, dynamic>? _status;
  Timer? _statusTimer;
  bool _isConnected = true;
  int _currentVolume = 50;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
    _fetchVolume();
    // Poll status every 5 seconds
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchStatus();
      _fetchVolume();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchStatus() async {
    final status = await _service.getStatus();
    if (!mounted) return;
    setState(() {
      _status = status;
      _isConnected = _service.isConnected;
    });
  }

  Future<void> _fetchVolume() async {
    final vol = await _service.volumeGet();
    if (!mounted) return;
    if (vol != null) {
      setState(() => _currentVolume = vol);
    }
  }

  Future<void> _volumeUp() async {
    final newVol = (_currentVolume + 10).clamp(0, 100);
    await _service.volumeSet(newVol);
    setState(() => _currentVolume = newVol);
  }

  Future<void> _volumeDown() async {
    final newVol = (_currentVolume - 10).clamp(0, 100);
    await _service.volumeSet(newVol);
    setState(() => _currentVolume = newVol);
  }

  Future<void> _disconnect() async {
    await _service.clearConnection();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PairingScreen()),
    );
  }

  /// Execute an action immediately (no confirmation) — for volume/media
  Future<void> _execute(String action, Future<bool> Function() command) async {
    final success = await command();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '$action success' : 'Failed: $action'),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// Show confirmation dialog, then execute — for power actions only
  Future<void> _confirmAndExecute(String title, String action, Future<bool> Function() command) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Action', style: TextStyle(color: Colors.white)),
        content: Text('$title?', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm',
                style: TextStyle(color: Color(0xFFE94560), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final success = await command();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '$action executed' : 'Failed: $action'),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flight_takeoff, size: 22),
            SizedBox(width: 8),
            Text('PocketPilot'),
          ],
        ),
        actions: [
          if (!_isConnected)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, size: 14, color: Colors.red),
                  SizedBox(width: 4),
                  Text('Disconnected', style: TextStyle(fontSize: 11, color: Colors.red)),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStatus,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'disconnect') _disconnect();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'info',
                enabled: false,
                child: Text('Server: ${_service.baseUrl}', style: const TextStyle(fontSize: 12)),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'disconnect',
                child: Row(
                  children: [
                    Icon(Icons.link_off, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Disconnect', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchStatus,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              _buildStatusCard(),
              const SizedBox(height: 24),

              // Quick Actions Grid
              const Text('Quick Actions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              _buildQuickActionsGrid(),

              const SizedBox(height: 24),

              // Feature Tiles
              const Text('Features',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              _buildFeatureTiles(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _isConnected ? const Color(0xFF0F3460) : Colors.grey.shade800,
            _isConnected ? const Color(0xFF16213E) : Colors.grey.shade900,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isConnected
              ? const Color(0xFFE94560).withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isConnected ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isConnected ? Icons.check_circle : Icons.error,
                  color: _isConnected ? Colors.green : Colors.red,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isConnected ? 'Connected' : 'Disconnected',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isConnected ? Colors.green : Colors.red,
                      ),
                    ),
                    if (_status?['hostname'] != null) ...[
                      const SizedBox(height: 4),
                      Text('Host: ${_status!['hostname']}',
                          style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                    ],
                    if (_status?['platform'] != null) ...[
                      Text('OS: ${_status!['platform']}',
                          style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Metrics row
          Row(
            children: [
              _buildMetricChip(
                Icons.memory,
                'CPU',
                _status?['cpu_percent'] != null ? '${_status!['cpu_percent']}%' : '--',
              ),
              const SizedBox(width: 8),
              _buildMetricChip(
                Icons.storage,
                'RAM',
                _status?['memory_percent'] != null ? '${_status!['memory_percent']}%' : '--',
              ),
              const SizedBox(width: 8),
              _buildMetricChip(
                Icons.battery_std,
                'Battery',
                _status?['battery_percent'] != null
                    ? '${_status!['battery_percent']}%${_status!['battery_charging'] == true ? " ⚡" : ""}'
                    : '--',
              ),
              const SizedBox(width: 8),
              _buildMetricChip(
                Icons.language,
                'IP',
                _status?['ip'] ?? '--',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: const Color(0xFFE94560)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    final actions = [
      _ActionItem(Icons.volume_up, 'Vol +', Colors.teal, _volumeUp),
      _ActionItem(Icons.volume_down, 'Vol -', Colors.teal, _volumeDown),
      _ActionItem(Icons.volume_off, 'Mute', Colors.cyan, () =>
          _execute('Mute', _service.volumeMute)),
      _ActionItem(Icons.lock, 'Lock', Colors.blueGrey, () =>
          _execute('Lock', _service.powerLock)),
      // _ActionItem(Icons.power_settings_new, 'Shutdown', Colors.red, () =>
      //     _confirmAndExecute('Shutdown computer?', 'Shutdown', _service.powerShutdown)),
      // _ActionItem(Icons.restart_alt, 'Restart', Colors.orange, () =>
      //     _confirmAndExecute('Restart computer?', 'Restart', _service.powerRestart)),
      // _ActionItem(Icons.nightlight_round, 'Sleep', Colors.indigo, () =>
      //     _confirmAndExecute('Sleep computer?', 'Sleep', _service.powerSleep)),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: actions.length,
      itemBuilder: (ctx, index) => _buildActionButton(actions[index]),
    );
  }

  Widget _buildActionButton(_ActionItem item) {
    return Material(
      color: item.color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: item.color.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: item.color, size: 28),
              const SizedBox(height: 6),
              Text(item.label, textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[300], fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureTiles() {
    final features = [
      // _FeatureItem(Icons.touch_app, 'Trackpad', 'Full-screen gesture trackpad\nwith WebSocket low latency',
      //     const Color(0xFF0F3460), () {
      //   Navigator.push(context, MaterialPageRoute(
      //       builder: (_) => TrackpadScreen(service: _service)));
      // }),
      // _FeatureItem(Icons.keyboard, 'Keyboard', 'Send text, special keys,\nand shortcuts',
      //     const Color(0xFF1A1A2E), () {
      //   Navigator.push(context, MaterialPageRoute(
      //       builder: (_) => KeyboardScreen(service: _service)));
      // }),
      _FeatureItem(Icons.power_settings_new, 'Power Controls', 'Shutdown, Sleep, Lock\nwith confirmation dialogs',
          const Color(0xFF16213E), () {
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => PowerScreen(service: _service)));
      }),
      _FeatureItem(Icons.tv, 'Screen Mirror', 'Live screenshots every 1-2s\n(low quality for speed)',
          const Color(0xFF0F3460), () {
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => ScreenMirrorScreen(service: _service)));
      }),
      // _FeatureItem(Icons.music_note, 'Media Controls', 'Play/Pause, Next/Prev\nmusic and video',
      //     const Color(0xFF0F3460), () {
      //   Navigator.push(context, MaterialPageRoute(
      //       builder: (_) => MediaScreen(service: _service)));
      // }),
      // _FeatureItem(Icons.rocket_launch, 'App Launcher', 'Launch apps with\npresets or custom name',
      //     const Color(0xFF1A1A2E), () {
      //   Navigator.push(context, MaterialPageRoute(
      //       builder: (_) => AppLauncherScreen(service: _service)));
      // }),
      // _FeatureItem(Icons.volume_up, 'Volume Control', 'Precise volume slider\nwith presets and mute',
      //     const Color(0xFF16213E), () {
      //   Navigator.push(context, MaterialPageRoute(
      //       builder: (_) => VolumeScreen(service: _service)));
      // }),
      _FeatureItem(Icons.settings_display, 'Laptop Settings', 'Change wallpaper,\nbrightness & display',
          const Color(0xFF16213E), () {
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => LaptopSettingsScreen(service: _service)));
      }),
      _FeatureItem(Icons.folder_open, 'File Browser', 'Browse and navigate\nlaptop filesystem',
          const Color(0xFF1A1A2E), () {
        Navigator.push(context, MaterialPageRoute(
            builder: (_) => FileBrowserScreen(service: _service)));
      }),
    ];

    return Column(
      children: features.map((f) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: f.color.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: f.onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Icon(f.icon, color: const Color(0xFFE94560), size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(f.subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
        ),
      )).toList(),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  _ActionItem(this.icon, this.label, this.color, this.onTap);
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  _FeatureItem(this.icon, this.title, this.subtitle, this.color, this.onTap);
}