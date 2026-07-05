import 'package:flutter/material.dart';
import '../services/pocketpilot_service.dart';

class VolumeScreen extends StatefulWidget {
  final PocketPilotService service;

  const VolumeScreen({super.key, required this.service});

  @override
  State<VolumeScreen> createState() => _VolumeScreenState();
}

class _VolumeScreenState extends State<VolumeScreen> {
  PocketPilotService get _service => widget.service;
  double _volume = 50;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVolume();
  }

  Future<void> _fetchVolume() async {
    final vol = await _service.volumeGet();
    if (!mounted) return;
    setState(() {
      if (vol != null) _volume = vol.toDouble();
      _isLoading = false;
    });
  }

  Future<void> _setVolume(double value) async {
    setState(() => _volume = value);
    await _service.volumeSet(value.round());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.volume_up, size: 22),
            SizedBox(width: 8),
            Text('Volume Control'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE94560)))
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Volume icon
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFF16213E),
                        borderRadius: BorderRadius.circular(60),
                        border: Border.all(
                          color: const Color(0xFFE94560).withOpacity(0.3),
                        ),
                      ),
                      child: Icon(
                        _volume == 0
                            ? Icons.volume_off
                            : _volume < 50
                                ? Icons.volume_down
                                : Icons.volume_up,
                        size: 56,
                        color: const Color(0xFFE94560),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Volume percentage
                    Text(
                      '${_volume.round()}%',
                      style: const TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Slider
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: const Color(0xFFE94560),
                        inactiveTrackColor: const Color(0xFF16213E),
                        thumbColor: const Color(0xFFE94560),
                        overlayColor: const Color(0xFFE94560).withOpacity(0.2),
                        trackHeight: 6,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                      ),
                      child: Slider(
                        value: _volume,
                        min: 0,
                        max: 100,
                        divisions: 100,
                        onChanged: _setVolume,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick preset buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildPresetButton('0%', 0),
                        const SizedBox(width: 12),
                        _buildPresetButton('25%', 25),
                        const SizedBox(width: 12),
                        _buildPresetButton('50%', 50),
                        const SizedBox(width: 12),
                        _buildPresetButton('75%', 75),
                        const SizedBox(width: 12),
                        _buildPresetButton('100%', 100),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Mute button
                    Material(
                      color: _volume == 0
                          ? const Color(0xFFE94560).withOpacity(0.2)
                          : const Color(0xFF16213E),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () async {
                          await _service.volumeMute();
                          // Refresh volume after toggle
                          _fetchVolume();
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 200,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.volume_off,
                                color: _volume == 0
                                    ? const Color(0xFFE94560)
                                    : Colors.grey[400],
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Toggle Mute',
                                style: TextStyle(
                                  color: _volume == 0
                                      ? const Color(0xFFE94560)
                                      : Colors.grey[400],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPresetButton(String label, int value) {
    final isActive = _volume.round() == value;
    return Material(
      color: isActive ? const Color(0xFFE94560) : const Color(0xFF16213E),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _setVolume(value.toDouble()),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey[400],
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}