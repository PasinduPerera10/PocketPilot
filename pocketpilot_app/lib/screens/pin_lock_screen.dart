import 'package:flutter/material.dart';
import '../services/pocketpilot_service.dart';
import 'pairing_screen.dart';

class PinLockScreen extends StatefulWidget {
  final PocketPilotService service;

  const PinLockScreen({super.key, required this.service});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  PocketPilotService get _service => widget.service;
  String _enteredPin = '';
  bool _isError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkPinSetup();
  }

  Future<void> _checkPinSetup() async {
    final hasPin = await _service.hasPin();
    if (!mounted) return;
    if (!hasPin) {
      // No PIN set — go to create PIN screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _CreatePinScreen(service: _service),
        ),
      );
    }
  }

  void _onDigitPressed(String digit) {
    if (_enteredPin.length >= 4) return;
    setState(() {
      _enteredPin += digit;
      _isError = false;
    });

    if (_enteredPin.length == 4) {
      _verifyPin();
    }
  }

  void _onDeletePressed() {
    if (_enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _isError = false;
    });
  }

  Future<void> _verifyPin() async {
    final valid = await _service.verifyPin(_enteredPin);
    if (!mounted) return;

    if (valid) {
      // Navigate to pairing screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PairingScreen(service: _service),
        ),
      );
    } else {
      setState(() {
        _enteredPin = '';
        _isError = true;
        _errorMessage = 'Wrong PIN. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),

            // Logo
            const Icon(Icons.lock_outline, size: 64, color: Color(0xFFE94560)),
            const SizedBox(height: 16),
            const Text('Enter PIN',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text('Unlock PocketPilot',
                style: TextStyle(fontSize: 14, color: Colors.grey[400])),

            const SizedBox(height: 32),

            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _enteredPin.length
                        ? const Color(0xFFE94560)
                        : Colors.grey.shade700,
                  ),
                );
              }),
            ),

            if (_isError) ...[
              const SizedBox(height: 16),
              Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 14)),
            ],

            const Spacer(flex: 1),

            // Number pad
            _buildNumberPad(),

            const Spacer(flex: 1),

            // Forgot PIN
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF16213E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('Reset PIN?', style: TextStyle(color: Colors.white)),
                    content: const Text(
                      'This will clear the app PIN. You also need to re-enter the server connection.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Reset All',
                            style: TextStyle(color: Color(0xFFE94560), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _service.clearPin();
                  await _service.clearConnection();
                  if (!mounted) return;
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PairingScreen(service: _service),
                    ),
                  );
                }
              },
              child: Text('Forgot PIN?', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          _buildNumberRow(['1', '2', '3']),
          _buildNumberRow(['4', '5', '6']),
          _buildNumberRow(['7', '8', '9']),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 72),
              _buildNumberButton('0'),
              GestureDetector(
                onTap: _onDeletePressed,
                child: Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  child: const Icon(Icons.backspace_outlined,
                      color: Colors.white, size: 28),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumberRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildNumberButton(d)).toList(),
    );
  }

  Widget _buildNumberButton(String digit) {
    return GestureDetector(
      onTap: () => _onDigitPressed(digit),
      child: Container(
        width: 72,
        height: 72,
        margin: const EdgeInsets.all(4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(digit,
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

// ==================== CREATE PIN SCREEN ====================

class _CreatePinScreen extends StatefulWidget {
  final PocketPilotService service;
  const _CreatePinScreen({required this.service});

  @override
  State<_CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<_CreatePinScreen> {
  PocketPilotService get _service => widget.service;
  String _pin = '';
  String? _confirmPin;
  bool _isError = false;
  String _errorMessage = '';

  void _onDigitPressed(String digit) {
    if (_confirmPin != null) {
      // Confirming
      if (_confirmPin!.length >= 4) return;
      setState(() {
        _confirmPin = _confirmPin! + digit;
        _isError = false;
      });

      if (_confirmPin!.length == 4) {
        _finishSetup();
      }
    } else {
      // Entering first PIN
      if (_pin.length >= 4) return;
      setState(() {
        _pin += digit;
        _isError = false;
      });

      if (_pin.length == 4) {
        // Move to confirm
        setState(() {
          _confirmPin = '';
        });
      }
    }
  }

  void _onDeletePressed() {
    if (_confirmPin != null) {
      if (_confirmPin!.isEmpty) {
        setState(() => _confirmPin = null);
        return;
      }
      setState(() => _confirmPin = _confirmPin!.substring(0, _confirmPin!.length - 1));
    } else {
      if (_pin.isEmpty) return;
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
    setState(() => _isError = false);
  }

  Future<void> _finishSetup() async {
    if (_pin != _confirmPin) {
      setState(() {
        _pin = '';
        _confirmPin = null;
        _isError = true;
        _errorMessage = 'PINs don\'t match. Try again.';
      });
      return;
    }

    await _service.savePin(_pin);
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PairingScreen(service: _service),
      ),
    );
  }

  void _skip() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PairingScreen(service: _service),
      ),
    );
  }

  int _currentLength() {
    if (_confirmPin != null) return _confirmPin!.length;
    return _pin.length;
  }

  @override
  Widget build(BuildContext context) {
    final isConfirming = _confirmPin != null;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),

            // Logo
            const Icon(Icons.lock_open, size: 64, color: Color(0xFFE94560)),
            const SizedBox(height: 16),
            Text(
              isConfirming ? 'Confirm PIN' : 'Set App PIN',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              isConfirming
                  ? 'Re-enter the PIN to confirm'
                  : 'Create a 4-digit PIN to lock the app',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),

            const SizedBox(height: 32),

            // PIN dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _currentLength()
                        ? const Color(0xFFE94560)
                        : Colors.grey.shade700,
                  ),
                );
              }),
            ),

            if (_isError) ...[
              const SizedBox(height: 16),
              Text(_errorMessage, style: const TextStyle(color: Colors.red, fontSize: 14)),
            ],

            const Spacer(flex: 1),

            // Number pad
            _buildNumberPad(),

            const Spacer(flex: 1),

            // Skip button
            if (!isConfirming)
              TextButton(
                onPressed: _skip,
                child: Text('Skip (no PIN)',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          _buildNumberRow(['1', '2', '3']),
          _buildNumberRow(['4', '5', '6']),
          _buildNumberRow(['7', '8', '9']),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 72),
              _buildNumberButton('0'),
              GestureDetector(
                onTap: _onDeletePressed,
                child: Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  child: const Icon(Icons.backspace_outlined,
                      color: Colors.white, size: 28),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNumberRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildNumberButton(d)).toList(),
    );
  }

  Widget _buildNumberButton(String digit) {
    return GestureDetector(
      onTap: () => _onDigitPressed(digit),
      child: Container(
        width: 72,
        height: 72,
        margin: const EdgeInsets.all(4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(digit,
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w500)),
      ),
    );
  }
}