import 'package:flutter/material.dart';
import '../services/pocketpilot_service.dart';
import 'dashboard_screen.dart';
import 'pin_lock_screen.dart';

class PairingScreen extends StatefulWidget {
  final PocketPilotService? service;

  const PairingScreen({super.key, this.service});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  late final PocketPilotService _service = widget.service ?? PocketPilotService();
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '8000');
  bool _isConnecting = false;
  bool _isLoadingSaved = true;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    _loadSavedConnection();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedConnection() async {
    final saved = await _service.loadSavedConnection();
    if (!mounted) return;

    if (saved != null) {
      _ipController.text = saved['ip'] ?? '';
      _portController.text = saved['port'] ?? '8000';
    }
    setState(() => _isLoadingSaved = false);
  }

  Future<void> _connect() async {
    final ip = _ipController.text.trim();
    final portStr = _portController.text.trim();
    final port = int.tryParse(portStr) ?? 8000;

    if (ip.isEmpty) {
      _showError('Please enter the laptop IP address');
      return;
    }

    setState(() => _isConnecting = true);

    // Only save if "Remember me" is checked
    if (_rememberMe) {
      await _service.saveConnection(ip, port: port);
    } else {
      // Set base URL in memory without persisting
      await _service.saveConnection(ip, port: port);
      // Immediately clear persisted settings so it won't auto-connect next time
      await _service.clearPersistedConnection();
    }

    final connected = await _service.testConnection();

    if (!mounted) return;

    if (connected) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(service: _service),
        ),
      );
    } else {
      setState(() => _isConnecting = false);
      _showError('Could not connect to server. Check IP and port.');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSaved) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.flight_takeoff, size: 80, color: Color(0xFFE94560)),
              const SizedBox(height: 16),
              const Text('PocketPilot',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold,
                      color: Colors.white, letterSpacing: 2)),
              const SizedBox(height: 32),
              const CircularProgressIndicator(color: Color(0xFFE94560)),
              const SizedBox(height: 16),
              Text('Loading...', style: TextStyle(color: Colors.grey[400])),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.flight_takeoff, size: 80, color: Color(0xFFE94560)),
                const SizedBox(height: 16),
                const Text('PocketPilot',
                    style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold,
                        color: Colors.white, letterSpacing: 2)),
                const SizedBox(height: 8),
                Text('Remote Laptop Control',
                    style: TextStyle(fontSize: 16, color: Colors.grey[400])),
                const SizedBox(height: 40),

                // IP Address
                TextField(
                  controller: _ipController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Laptop IP Address',
                    hintText: 'e.g. 192.168.1.100',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    prefixIcon: const Icon(Icons.computer, color: Color(0xFFE94560)),
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
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),

                // Port
                TextField(
                  controller: _portController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Port (default: 8000)',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.settings_ethernet, color: Color(0xFFE94560)),
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
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),

                // Remember Me checkbox
                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (val) => setState(() => _rememberMe = val ?? true),
                        activeColor: const Color(0xFFE94560),
                        checkColor: Colors.white,
                        side: const BorderSide(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => setState(() => _rememberMe = !_rememberMe),
                      child: Text(
                        'Remember me',
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Connect Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isConnecting ? null : _connect,
                    child: _isConnecting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Connect', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 24),

                // Instructions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16213E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade800),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.grey[400], size: 18),
                          const SizedBox(width: 8),
                          Text('How to connect',
                              style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '1. Run python server.py on your laptop\n'
                        '2. Make sure phone is on same WiFi network\n'
                        '3. Enter the laptop IP shown in terminal',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}