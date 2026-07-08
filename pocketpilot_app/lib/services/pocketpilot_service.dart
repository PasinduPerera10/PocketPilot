import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PocketPilotService {
  String _baseUrl = '';
  WebSocketChannel? _wsChannel;
  final Duration timeout = const Duration(seconds: 5);

  // Connection state
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String get baseUrl => _baseUrl;

  // ==================== PIN LOCK ====================

  /// Save a PIN code for app lock
  Future<void> savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_pin', pin);
  }

  /// Check if a PIN is set
  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('app_pin') && (prefs.getString('app_pin')?.isNotEmpty ?? false);
  }

  /// Verify the entered PIN
  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('app_pin');
    return savedPin == pin;
  }

  /// Clear the PIN
  Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('app_pin');
  }

  // ==================== SAVE / LOAD / CLEAR CONNECTION ====================

  /// Load saved connection from SharedPreferences
  Future<Map<String, String>?> loadSavedConnection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ip = prefs.getString('server_ip');
      final port = prefs.getInt('server_port') ?? 8000;

      if (ip != null && ip.isNotEmpty) {
        _baseUrl = 'http://$ip:$port';
        return {'ip': ip, 'port': port.toString()};
      }
    } catch (e) {
      debugPrint('Error loading saved connection: $e');
    }
    return null;
  }

  /// Save connection to SharedPreferences
  Future<void> saveConnection(String ip, {int port = 8000}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server_ip', ip);
      await prefs.setInt('server_port', port);
      _baseUrl = 'http://$ip:$port';
    } catch (e) {
      debugPrint('Error saving connection: $e');
    }
  }

  /// Clear saved connection (full disconnect + remove persisted data)
  Future<void> clearConnection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('server_ip');
      await prefs.remove('server_port');
      _baseUrl = '';
      _isConnected = false;
      disconnectWebSocket();
    } catch (e) {
      debugPrint('Error clearing connection: $e');
    }
  }

  /// Clear only persisted connection data (keeps in-memory baseUrl for current session)
  Future<void> clearPersistedConnection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('server_ip');
      await prefs.remove('server_port');
    } catch (e) {
      debugPrint('Error clearing persisted connection: $e');
    }
  }

  /// Ping the server to verify connection
  Future<bool> testConnection() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/status'),
          )
          .timeout(timeout);
      _isConnected = response.statusCode == 200;
      return _isConnected;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  // ==================== HELPER ====================

  Future<Map<String, dynamic>?> _get(String endpoint) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl$endpoint'))
          .timeout(timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('GET $endpoint failed: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('GET $endpoint error: $e');
    }
    _isConnected = false;
    return null;
  }

  Future<Map<String, dynamic>?> _post(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl$endpoint'),
            headers: {'Content-Type': 'application/json'},
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);
      if (response.statusCode == 200) {
        _isConnected = true;
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      debugPrint('POST $endpoint failed: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('POST $endpoint error: $e');
    }
    _isConnected = false;
    return null;
  }

  // ==================== STATUS ====================

  /// Get full status: battery, CPU, RAM, IP
  Future<Map<String, dynamic>?> getStatus() async {
    final result = await _get('/status');
    if (result != null) _isConnected = true;
    return result;
  }

  // ==================== POWER ====================

  Future<bool> powerShutdown() async {
    final result = await _post('/power/shutdown');
    return result?['status'] == 'ok';
  }

  Future<bool> powerRestart() async {
    final result = await _post('/power/restart');
    return result?['status'] == 'ok';
  }

  Future<bool> powerSleep() async {
    final result = await _post('/power/sleep');
    return result?['status'] == 'ok';
  }

  Future<bool> powerLock() async {
    final result = await _post('/power/lock');
    return result?['status'] == 'ok';
  }

  // ==================== VOLUME ====================

  /// Get current volume level (0-100), returns null on failure
  Future<int?> volumeGet() async {
    final result = await _get('/volume');
    if (result != null && result['volume'] != null) {
      return result['volume'] as int;
    }
    return null;
  }

  Future<bool> volumeSet(int level) async {
    final result = await _post('/volume/set', body: {'level': level});
    return result?['status'] == 'ok';
  }

  Future<bool> volumeMute() async {
    final result = await _post('/volume/mute');
    return result?['status'] == 'ok';
  }

  // ==================== SCREENSHOT ====================

  /// Fetch screenshot as JPEG bytes
  Future<Uint8List?> getScreenshot() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/screenshot'))
          .timeout(timeout);
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        _isConnected = true;
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('Screenshot error: $e');
    }
    _isConnected = false;
    return null;
  }

  // ==================== MOUSE ====================

  Future<bool> mouseMove(int dx, int dy) async {
    final result = await _post('/mouse/move', body: {'dx': dx, 'dy': dy});
    return result?['status'] == 'ok';
  }

  Future<bool> mouseClick({String button = 'left'}) async {
    final result = await _post('/mouse/click', body: {'button': button});
    return result?['status'] == 'ok';
  }

  // ==================== KEYBOARD ====================

  Future<bool> keyboardType(String text) async {
    final result = await _post('/keyboard/type', body: {'text': text});
    return result?['status'] == 'ok';
  }

  Future<bool> keyboardKey(String key) async {
    final result = await _post('/keyboard/key', body: {'key': key});
    return result?['status'] == 'ok';
  }

  // ==================== MEDIA ====================

  Future<bool> mediaPlayPause() async {
    final result = await _post('/media/play_pause');
    return result?['status'] == 'ok';
  }

  Future<bool> mediaNext() async {
    final result = await _post('/media/next');
    return result?['status'] == 'ok';
  }

  Future<bool> mediaPrev() async {
    final result = await _post('/media/prev');
    return result?['status'] == 'ok';
  }

  // ==================== APP ====================

  Future<bool> appOpen(String name) async {
    final result = await _post('/app/open', body: {'name': name});
    return result?['status'] == 'ok';
  }

  // ==================== FILE BROWSER ====================

  Future<Map<String, dynamic>?> listFiles({String path = '.'}) async {
    final result = await _get('/files?path=${Uri.encodeComponent(path)}');
    return result;
  }

  // ==================== WALLPAPER ====================

  /// Get wallpaper sources (directories with images)
  Future<Map<String, dynamic>?> getWallpaperSources() async {
    final result = await _get('/wallpaper/sources');
    return result;
  }

  /// Set desktop wallpaper from a file path
  Future<bool> setWallpaper(String path) async {
    final result = await _post('/wallpaper/set', body: {'path': path});
    return result?['status'] == 'ok';
  }

  // ==================== BRIGHTNESS ====================

  /// Get current screen brightness level (0-100), returns null on failure
  Future<int?> brightnessGet() async {
    final result = await _get('/brightness');
    if (result != null && result['brightness'] != null) {
      return result['brightness'] as int;
    }
    return null;
  }

  /// Set screen brightness level (0-100)
  Future<bool> brightnessSet(int level) async {
    final result = await _post('/brightness/set', body: {'level': level});
    return result?['status'] == 'ok';
  }

  // ==================== WEBSOCKET (Live Trackpad) ====================

  /// Connect to WebSocket for low-latency trackpad control
  bool connectWebSocket() {
    try {
      if (_baseUrl.isEmpty) return false;

      final wsUrl = _baseUrl.replaceFirst('http://', 'ws://');
      _wsChannel = WebSocketChannel.connect(Uri.parse('$wsUrl/ws/mouse'));

      _isConnected = true;
      return true;
    } catch (e) {
      debugPrint('WebSocket connect error: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Send mouse move via WebSocket
  void wsMouseMove(int dx, int dy) {
    try {
      _wsChannel?.sink.add(jsonEncode({
        'type': 'move',
        'dx': dx,
        'dy': dy,
      }));
    } catch (e) {
      debugPrint('WS send error: $e');
    }
  }

  /// Send mouse click via WebSocket
  void wsMouseClick({String button = 'left'}) {
    try {
      _wsChannel?.sink.add(jsonEncode({
        'type': 'click',
        'button': button,
      }));
    } catch (e) {
      debugPrint('WS send error: $e');
    }
  }

  /// Send scroll via WebSocket
  void wsScroll(int clicks) {
    try {
      _wsChannel?.sink.add(jsonEncode({
        'type': 'scroll',
        'clicks': clicks,
      }));
    } catch (e) {
      debugPrint('WS send error: $e');
    }
  }

  /// Send drag via WebSocket
  void wsDrag(int dx, int dy) {
    try {
      _wsChannel?.sink.add(jsonEncode({
        'type': 'drag',
        'dx': dx,
        'dy': dy,
      }));
    } catch (e) {
      debugPrint('WS send error: $e');
    }
  }

  void disconnectWebSocket() {
    try {
      _wsChannel?.sink.close();
      _wsChannel = null;
    } catch (_) {}
  }
}