import 'package:flutter/material.dart';
import '../services/pocketpilot_service.dart';

class TrackpadScreen extends StatefulWidget {
  final PocketPilotService service;

  const TrackpadScreen({super.key, required this.service});

  @override
  State<TrackpadScreen> createState() => _TrackpadScreenState();
}

class _TrackpadScreenState extends State<TrackpadScreen> {
  PocketPilotService get _service => widget.service;
  bool _wsConnected = false;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _connectWs();
  }

  @override
  void dispose() {
    _service.disconnectWebSocket();
    super.dispose();
  }

  void _connectWs() {
    final connected = _service.connectWebSocket();
    setState(() => _wsConnected = connected);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final dx = details.delta.dx.round();
    final dy = details.delta.dy.round();

    if (_isDragging) {
      _service.wsDrag(dx, dy);
    } else {
      _service.wsMouseMove(dx, dy);
    }
  }

  void _onTapUp(TapUpDetails details) {
    _service.wsMouseClick(button: 'left');
  }

  void _onLongPressStart(LongPressStartDetails details) {
    setState(() => _isDragging = true);
    _service.wsMouseClick(button: 'left');
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    setState(() => _isDragging = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trackpad'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _wsConnected ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _wsConnected ? Icons.wifi : Icons.wifi_off,
                  size: 14,
                  color: _wsConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  _wsConnected ? 'Live' : 'Offline',
                  style: TextStyle(
                    fontSize: 11,
                    color: _wsConnected ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
          if (!_wsConnected)
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _connectWs,
              tooltip: 'Reconnect WebSocket',
            ),
        ],
      ),
      body: Column(
        children: [
          // Trackpad area
          Expanded(
            child: GestureDetector(
              onPanUpdate: _onPanUpdate,
              onTapUp: _onTapUp,
              onLongPressStart: _onLongPressStart,
              onLongPressEnd: _onLongPressEnd,
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF16213E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isDragging
                        ? const Color(0xFFE94560)
                        : Colors.grey.shade800,
                    width: _isDragging ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isDragging ? Icons.drag_indicator : Icons.touch_app,
                      size: 64,
                      color: _isDragging
                          ? const Color(0xFFE94560)
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isDragging ? 'Dragging...' : 'Swipe to move mouse',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to click | Long press & drag to drag',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F3460),
              border: Border(top: BorderSide(color: Colors.grey.shade800)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(Icons.arrow_upward, 'Up', () {
                  _service.wsMouseMove(0, -50);
                }),
                _buildControlButton(Icons.arrow_downward, 'Down', () {
                  _service.wsMouseMove(0, 50);
                }),
                _buildControlButton(Icons.arrow_back, 'Left', () {
                  _service.wsMouseMove(-50, 0);
                }),
                _buildControlButton(Icons.arrow_forward, 'Right', () {
                  _service.wsMouseMove(50, 0);
                }),
                _buildControlButton(Icons.mouse, 'Left', () {
                  _service.wsMouseClick(button: 'left');
                }),
                _buildControlButton(Icons.mouse, 'Right', () {
                  _service.wsMouseClick(button: 'right');
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}