import 'package:flutter/material.dart';
import '../services/pocketpilot_service.dart';

class KeyboardScreen extends StatefulWidget {
  final PocketPilotService service;

  const KeyboardScreen({super.key, required this.service});

  @override
  State<KeyboardScreen> createState() => _KeyboardScreenState();
}

class _KeyboardScreenState extends State<KeyboardScreen> {
  PocketPilotService get _service => widget.service;
  final _textController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _textController.text;
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    final success = await _service.keyboardType(text);
    if (success) {
      _textController.clear();
    }
    if (!mounted) return;

    setState(() => _isSending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Text sent (${text.length} chars)' : 'Failed to send text'),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _sendKey(String key) {
    _service.keyboardKey(key);
  }

  Future<void> _openApp() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF16213E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Open Application', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g. chrome, notepad, terminal',
              hintStyle: TextStyle(color: Colors.grey[600]),
              filled: true,
              fillColor: const Color(0xFF1A1A2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Open', style: TextStyle(color: Color(0xFFE94560))),
            ),
          ],
        );
      },
    );

    if (name != null && name.isNotEmpty) {
      final success = await _service.appOpen(name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Opening: $name' : 'Failed to open: $name'),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keyboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: _openApp,
            tooltip: 'Open Application',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text input
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Type Text',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _textController,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter text to type on laptop...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      filled: true,
                      fillColor: const Color(0xFF1A1A2E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE94560)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _sendText,
                      child: _isSending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Send Text'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Special keys
            const Text('Special Keys',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            _buildKeyGrid(),

            const SizedBox(height: 24),

            // Navigation cluster
            const Text('Navigation',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            _buildNavigationCluster(),

            const SizedBox(height: 24),

            // Media controls
            const Text('Media Controls',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            _buildMediaControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyGrid() {
    final keys = [
      ['Enter', 'Tab', 'Esc'],
      ['Backspace', 'Delete', 'Space'],
      ['Home', 'End', 'PgUp', 'PgDn'],
    ];

    return Column(
      children: keys.map((row) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: row.map((key) => Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildKeyButton(key),
            ),
          )).toList(),
        ),
      )).toList(),
    );
  }

  Widget _buildKeyButton(String key) {
    return Material(
      color: const Color(0xFF0F3460),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _sendKey(key.toLowerCase()),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Text(
            key,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationCluster() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Arrow keys in diamond layout
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 60),
              _buildArrowButton(Icons.arrow_upward, 'up'),
              const SizedBox(width: 60),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildArrowButton(Icons.arrow_back, 'left'),
              const SizedBox(width: 12),
              _buildArrowButton(Icons.arrow_downward, 'down'),
              const SizedBox(width: 12),
              _buildArrowButton(Icons.arrow_forward, 'right'),
            ],
          ),
          const SizedBox(height: 16),
          // Function keys row
          Text('F1 - F12', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(12, (i) {
              final key = 'f${i + 1}';
              return Material(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => _sendKey(key),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 48,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    child: Text(key.toUpperCase(),
                        style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildArrowButton(IconData icon, String key) {
    return Material(
      color: const Color(0xFF0F3460),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _sendKey(key),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildMediaControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMediaButton(Icons.skip_previous, 'Previous', () => _service.mediaPrev()),
          _buildMediaButton(Icons.play_arrow, 'Play/Pause', () => _service.mediaPlayPause()),
          _buildMediaButton(Icons.skip_next, 'Next', () => _service.mediaNext()),
          _buildMediaButton(Icons.volume_up, 'Vol +', () => _service.volumeSet(100)),
          _buildMediaButton(Icons.volume_down, 'Vol -', () => _service.volumeSet(0)),
          _buildMediaButton(Icons.volume_off, 'Mute', () => _service.volumeMute()),
        ],
      ),
    );
  }

  Widget _buildMediaButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFE94560), size: 22),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 9)),
          ],
        ),
      ),
    );
  }
}