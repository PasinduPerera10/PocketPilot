import 'dart:io';
import 'package:flutter/material.dart';
import '../services/pocketpilot_service.dart';

class LaptopSettingsScreen extends StatefulWidget {
  final PocketPilotService service;

  const LaptopSettingsScreen({super.key, required this.service});

  @override
  State<LaptopSettingsScreen> createState() => _LaptopSettingsScreenState();
}

class _LaptopSettingsScreenState extends State<LaptopSettingsScreen> {
  PocketPilotService get _service => widget.service;

  bool _loading = true;
  int? _brightness;
  bool _settingBrightness = false;
  String? _currentWallpaper;

  // Wallpaper sources
  List<Map<String, dynamic>> _sources = [];
  int _selectedSourceIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    // Load brightness
    final brightness = await _service.brightnessGet();
    // Load wallpaper sources
    final sources = await _service.getWallpaperSources();

    if (!mounted) return;
    setState(() {
      _brightness = brightness ?? 50;
      if (sources != null) {
        _currentWallpaper = sources['current'] as String?;
        final srcList = sources['sources'] as List<dynamic>? ?? [];
        _sources = srcList.cast<Map<String, dynamic>>();
      }
      _loading = false;
    });
  }

  Future<void> _setBrightness(int level) async {
    setState(() {
      _brightness = level;
      _settingBrightness = true;
    });
    await _service.brightnessSet(level);
    if (!mounted) return;
    setState(() => _settingBrightness = false);
  }

  Future<void> _setWallpaper(String path) async {
    final success = await _service.setWallpaper(path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Wallpaper changed!' : 'Failed to set wallpaper'),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
    if (success) {
      setState(() => _currentWallpaper = path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings_display, size: 22),
            SizedBox(width: 8),
            Text('Laptop Settings'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE94560)))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---- Brightness Section ----
                    _buildSectionTitle(Icons.brightness_medium, 'Brightness'),
                    const SizedBox(height: 12),
                    _buildBrightnessCard(),
                    const SizedBox(height: 28),

                    // ---- Wallpaper Section ----
                    _buildSectionTitle(Icons.wallpaper, 'Desktop Wallpaper'),
                    const SizedBox(height: 12),
                    _buildCurrentWallpaper(),
                    const SizedBox(height: 16),
                    _buildSourceTabs(),
                    const SizedBox(height: 12),
                    _buildWallpaperGrid(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFE94560)),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ],
    );
  }

  // ==================== BRIGHTNESS ====================

  Widget _buildBrightnessCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Screen Brightness',
                  style: TextStyle(color: Colors.white, fontSize: 15)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE94560).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_brightness%',
                  style: const TextStyle(
                      color: Color(0xFFE94560),
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.brightness_low, color: Colors.grey[500], size: 20),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFE94560),
                    inactiveTrackColor: Colors.white.withOpacity(0.1),
                    thumbColor: const Color(0xFFE94560),
                    overlayColor: const Color(0xFFE94560).withOpacity(0.2),
                    valueIndicatorColor: const Color(0xFFE94560),
                    valueIndicatorTextStyle:
                        const TextStyle(color: Colors.white),
                  ),
                  child: Slider(
                    value: (_brightness ?? 50).toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: '$_brightness%',
                    onChanged: (val) {
                      setState(() => _brightness = val.toInt());
                    },
                    onChangeEnd: (val) {
                      _setBrightness(val.toInt());
                    },
                  ),
                ),
              ),
              Icon(Icons.brightness_high, color: Colors.grey[500], size: 20),
            ],
          ),
          if (_settingBrightness)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: LinearProgressIndicator(
                color: Color(0xFFE94560),
                backgroundColor: Colors.white12,
              ),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBrightnessQuickBtn('Dim', 20),
              _buildBrightnessQuickBtn('Low', 40),
              _buildBrightnessQuickBtn('Mid', 60),
              _buildBrightnessQuickBtn('High', 80),
              _buildBrightnessQuickBtn('Max', 100),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrightnessQuickBtn(String label, int level) {
    final isActive = _brightness == level;
    return GestureDetector(
      onTap: () => _setBrightness(level),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFE94560).withOpacity(0.3)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? const Color(0xFFE94560)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFFE94560) : Colors.grey[400],
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ==================== WALLPAPER ====================

  Widget _buildCurrentWallpaper() {
    if (_currentWallpaper == null) return const SizedBox.shrink();
    final fileName = _currentWallpaper!.split(Platform.pathSeparator).last;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          const Icon(Icons.image, color: Color(0xFFE94560), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Current: $fileName',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceTabs() {
    if (_sources.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('No wallpaper sources found',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _sources.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, index) {
          final src = _sources[index];
          final dirPath = src['path'] as String? ?? '';
          final dirName = dirPath.split(Platform.pathSeparator).last;
          final isSelected = _selectedSourceIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedSourceIndex = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFE94560).withOpacity(0.3)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFE94560)
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Text(
                dirName,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFE94560) : Colors.grey[400],
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWallpaperGrid() {
    if (_sources.isEmpty) return const SizedBox.shrink();

    final currentSource = _sources[_selectedSourceIndex];
    final images = (currentSource['images'] as List<dynamic>?) ?? [];

    if (images.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('No images in this folder',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.6,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: images.length,
      itemBuilder: (ctx, index) {
        final imagePath = images[index] as String;
        final fileName = imagePath.split(Platform.pathSeparator).last;
        final isCurrent = imagePath == _currentWallpaper;
        return Material(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => _setWallpaper(imagePath),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrent
                      ? const Color(0xFFE94560)
                      : Colors.white.withOpacity(0.05),
                  width: isCurrent ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image thumbnail
                  Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.black26,
                      child: const Icon(Icons.broken_image,
                          color: Colors.grey, size: 32),
                    ),
                  ),
                  // Overlay with filename
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.8),
                          ],
                        ),
                      ),
                      child: Text(
                        fileName,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  // Current indicator
                  if (isCurrent)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE94560),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 14),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}