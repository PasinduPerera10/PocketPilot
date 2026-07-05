import 'package:flutter/material.dart';
import '../services/pocketpilot_service.dart';

class AppLauncherScreen extends StatefulWidget {
  final PocketPilotService service;

  const AppLauncherScreen({super.key, required this.service});

  @override
  State<AppLauncherScreen> createState() => _AppLauncherScreenState();
}

class _AppLauncherScreenState extends State<AppLauncherScreen> {
  PocketPilotService get _service => widget.service;
  final _appController = TextEditingController();

  final List<Map<String, dynamic>> _presetApps = [
    {'name': 'notepad', 'icon': Icons.description, 'label': 'Notepad'},
    {'name': 'chrome', 'icon': Icons.language, 'label': 'Chrome'},
    {'name': 'firefox', 'icon': Icons.language, 'label': 'Firefox'},
    {'name': 'edge', 'icon': Icons.language, 'label': 'Edge'},
    {'name': 'code', 'icon': Icons.code, 'label': 'VS Code'},
    {'name': 'spotify', 'icon': Icons.music_note, 'label': 'Spotify'},
    {'name': 'explorer', 'icon': Icons.folder, 'label': 'File Explorer'},
    {'name': 'calculator', 'icon': Icons.calculate, 'label': 'Calculator'},
    {'name': 'cmd', 'icon': Icons.terminal, 'label': 'Command Prompt'},
    {'name': 'powershell', 'icon': Icons.terminal, 'label': 'PowerShell'},
    {'name': 'taskmgr', 'icon': Icons.dashboard, 'label': 'Task Manager'},
    {'name': 'control', 'icon': Icons.settings, 'label': 'Control Panel'},
  ];

  @override
  void dispose() {
    _appController.dispose();
    super.dispose();
  }

  Future<void> _launchApp(String name) async {
    final success = await _service.appOpen(name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Opening: $name' : 'Failed to open: $name'),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _launchCustomApp() async {
    final name = _appController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter an app name'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    _appController.clear();
    await _launchApp(name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rocket_launch, size: 22),
            SizedBox(width: 8),
            Text('App Launcher'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Custom app input
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _appController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Custom app name',
                      hintText: 'e.g. chrome, notepad',
                      labelStyle: TextStyle(color: Colors.grey[400]),
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFFE94560)),
                      filled: true,
                      fillColor: const Color(0xFF16213E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE94560), width: 2),
                      ),
                    ),
                    onSubmitted: (_) => _launchCustomApp(),
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: const Color(0xFFE94560),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _launchCustomApp,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 56,
                      height: 56,
                      child: const Icon(Icons.arrow_forward, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: Color(0xFF16213E)),
          ),

          // Preset apps grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Quick Launch',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  )),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.0,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _presetApps.length,
              itemBuilder: (ctx, index) {
                final app = _presetApps[index];
                return Material(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: () => _launchApp(app['name'] as String),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(app['icon'] as IconData,
                              color: const Color(0xFFE94560), size: 32),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              app['label'] as String,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[300], fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}