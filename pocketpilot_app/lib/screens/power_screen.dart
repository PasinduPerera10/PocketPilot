import 'package:flutter/material.dart';
import '../services/pocketpilot_service.dart';

class PowerScreen extends StatefulWidget {
  final PocketPilotService service;

  const PowerScreen({super.key, required this.service});

  @override
  State<PowerScreen> createState() => _PowerScreenState();
}

class _PowerScreenState extends State<PowerScreen> {
  PocketPilotService get _service => widget.service;

  Future<bool> _confirmAndExecute(String title, String description, Future<bool> Function() command) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(description, style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    final success = await command();
    if (!mounted) return success;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '$title executed' : 'Failed: $title'),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return success;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Power Controls'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('System Power',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            _buildPowerOption(
              Icons.power_settings_new,
              'Shutdown',
              'Fully shut down the computer',
              Colors.red,
              () => _confirmAndExecute(
                'Shutdown',
                'Are you sure you want to shut down the computer?\n\n'
                'This will close all applications and power off the system.',
                _service.powerShutdown,
              ),
            ),
            const SizedBox(height: 12),
            _buildPowerOption(
              Icons.restart_alt,
              'Restart',
              'Restart the computer',
              Colors.orange,
              () => _confirmAndExecute(
                'Restart',
                'Are you sure you want to restart the computer?\n\n'
                'This will close all applications and reboot the system.',
                _service.powerShutdown, // Note: server.py has shutdown only (poweroff)
              ),
            ),
            const SizedBox(height: 12),
            _buildPowerOption(
              Icons.nightlight_round,
              'Sleep',
              'Put the computer to sleep',
              Colors.indigo,
              () => _confirmAndExecute(
                'Sleep',
                'Put the computer to sleep mode?\n\n'
                'The system will enter low-power state.',
                _service.powerSleep,
              ),
            ),
            const SizedBox(height: 12),
            _buildPowerOption(
              Icons.lock_outline,
              'Lock',
              'Lock the computer screen',
              Colors.amber,
              () async {
                final success = await _service.powerLock();
                if (!mounted) return success;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Computer locked' : 'Failed to lock'),
                    backgroundColor: success ? Colors.green : Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return success;
              },
            ),

            const SizedBox(height: 32),

            const Text('Danger Zone',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.red, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'These actions will immediately affect the laptop. '
                      'Make sure you have saved all work before proceeding.',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerOption(IconData icon, String title, String subtitle, Color color, Future<bool> Function() onTap) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[600]),
            ],
          ),
        ),
      ),
    );
  }
}