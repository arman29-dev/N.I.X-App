import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_background_service/flutter_background_service.dart';

import '../services/device_ws.dart';
import '../utils/app_constants.dart';
import '../utils/appdata_storage.dart';
import '../utils/token_storage.dart';
import '../utils/app_colors.dart';
import 'custom_button.dart';

class StatsPanel extends StatefulWidget {
  final int tabIndex;
  final ValueChanged<int> onTabChanged;

  const StatsPanel({
    super.key,
    required this.tabIndex,
    required this.onTabChanged,
  });

  @override
  State<StatsPanel> createState() => _StatsPanelState();
}

class _StatsPanelState extends State<StatsPanel> {
  String serverStatus = 'Offline';
  String deviceStatus = 'Offline';
  int? _pingMs;
  bool _pinging = false;
  String? _selfDeviceUid;
  List<Map<String, dynamic>> _devices = [];
  StreamSubscription<Map<String, dynamic>>? _wsSub;
  void Function(bool connected)? _prevOnConnectionChange;

  @override
  void initState() {
    super.initState();
    _updateDeviceStatus();
    _connectWS();
    AppDataStorage.getDeviceUID().then((uid) => _selfDeviceUid = uid);
  }

  void _connectWS() {
    if (!DeviceWS().isConnected) {
      DeviceWS().connect();
    }
    _wsSub = DeviceWS().messages.listen(_handleWSMessage);

    _prevOnConnectionChange = DeviceWS().onConnectionChange;
    DeviceWS().onConnectionChange = (connected) {
      _prevOnConnectionChange?.call(connected);
      if (connected) {
        DeviceWS().sendCommand('get_devices');
        _measurePing();
        if (mounted) {
          setState(() => serverStatus = 'Online');
        }
      }
    };

    if (DeviceWS().isConnected) {
      DeviceWS().sendCommand('get_devices');
      _measurePing();
      setState(() => serverStatus = 'Online');
    } else {
      Future.delayed(const Duration(seconds: 2), () {
        if (!DeviceWS().isConnected && mounted) {
          setState(() => serverStatus = 'Connecting...');
        }
      });
    }
  }

  void _handleWSMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;

    if (type == 'command') {
      if (msg['action'] == 'logout') {
        _forceLogout();
        return;
      }
    }

    if (type == 'response') {
      final action = msg['action'] as String?;
      final data = msg['data'] as Map<String, dynamic>?;

      if (action == 'toggle_status' && data != null) {
        final isOnline = data['device_status'] as bool?;
        if (isOnline != null) {
          AppDataStorage.setDeviceStatus(isOnline);
          setState(() {
            deviceStatus = isOnline ? 'Online' : 'Offline';
            serverStatus = 'Online';
          });
        }
      } else if (action == 'refresh' && data != null) {
        final device = data['device'] as Map<String, dynamic>?;
        if (device != null) {
          final isOnline = device['is_active'] as bool? ?? true;
          AppDataStorage.setDeviceStatus(isOnline);
          setState(() {
            deviceStatus = isOnline ? 'Online' : 'Offline';
            serverStatus = 'Online';
          });
        }
      } else if (action == 'get_devices' && data != null) {
        final devices = data['devices'] as List<dynamic>?;
        if (devices != null) {
          final list = devices.cast<Map<String, dynamic>>();
          final self = list.firstWhere(
            (d) => d['uid'] == _selfDeviceUid,
            orElse: () => <String, dynamic>{},
          );
          if (self.isNotEmpty) {
            final isActive = self['is_active'] as bool? ?? true;
            AppDataStorage.setDeviceStatus(isActive);
          }
          setState(() {
            _devices = list;
            if (self.isNotEmpty) {
              deviceStatus = (self['is_active'] as bool? ?? true) ? 'Online' : 'Offline';
            }
          });
        }
      }
    } else if (type == 'event') {
      final event = msg['event'] as String?;
      final data = msg['data'] as Map<String, dynamic>?;

      if (event == 'device_status_change' && data != null) {
        _updateDeviceInList(data);
      } else if (event == 'device_online' && data != null) {
        _updateDeviceOnline(data['uid'] as String?, true);
        if (data['uid'] == _selfDeviceUid && mounted) {
          setState(() => serverStatus = 'Online');
        }
      } else if (event == 'device_offline' && data != null) {
        _updateDeviceOnline(data['uid'] as String?, false);
      } else if (event == 'device_added' && data != null) {
        setState(() => _devices.add(data));
      } else if (event == 'device_removed' && data != null) {
        final removedUid = data['uid'] as String?;
        if (removedUid != null) {
          setState(() {
            _devices.removeWhere((d) => d['uid'] == removedUid);
          });
        }
      } else if (event == 'device_renamed' && data != null) {
        final renamedUid = data['uid'] as String?;
        final newName = data['name'] as String?;
        if (renamedUid != null && newName != null) {
          setState(() {
            for (var i = 0; i < _devices.length; i++) {
              if (_devices[i]['uid'] == renamedUid) {
                _devices[i]['name'] = newName;
                break;
              }
            }
          });
        }
      }
    }
  }

  void _updateDeviceInList(Map<String, dynamic> data) {
    final uid = data['uid'] as String?;
    final isActive = data['is_active'] as bool?;
    if (uid == null || isActive == null) return;
    setState(() {
      for (var i = 0; i < _devices.length; i++) {
        if (_devices[i]['uid'] == uid) {
          _devices[i]['is_active'] = isActive;
          break;
        }
      }
    });
  }

  void _updateDeviceOnline(String? uid, bool online) {
    if (uid == null) return;
    setState(() {
      for (var i = 0; i < _devices.length; i++) {
        if (_devices[i]['uid'] == uid) {
          _devices[i]['is_online'] = online;
          break;
        }
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    if (_prevOnConnectionChange != null) {
      DeviceWS().onConnectionChange = _prevOnConnectionChange;
      _prevOnConnectionChange = null;
    }
    super.dispose();
  }

  Future<void> _measurePing() async {
    if (_pinging) return;
    setState(() => _pinging = true);
    final start = DateTime.now();
    try {
      await http.get(Uri.parse('${AppConstants.serverUrl}/ping'));
      final ms = DateTime.now().difference(start).inMilliseconds;
      if (mounted) {
        setState(() {
          _pingMs = ms;
          _pinging = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _pingMs = null;
          _pinging = false;
        });
      }
    }
  }

  Future<void> _updateDeviceStatus() async {
    final status = await AppDataStorage.getDeviceStatus();
    setState(() {
      deviceStatus = (status ?? true) ? 'Online' : 'Offline';
    });
    if (status == null) {
      await AppDataStorage.setDeviceStatus(true);
    }
  }

  void _refreshConnection() async {
    if (!DeviceWS().isConnected) {
      setState(() => serverStatus = 'Connecting...');
      await DeviceWS().connect();
      await Future.delayed(const Duration(seconds: 2));
    }
    if (DeviceWS().isConnected) {
      DeviceWS().sendCommand('get_devices');
      _measurePing();
      setState(() => serverStatus = 'Online');
    }
  }

  void _changeDeviceStatus() {
    DeviceWS().sendCommand('toggle_status');
  }



  Future<void> _forceLogout() async {
    await DeviceWS().disconnect();
    await AppDataStorage.clearAppData();
    await TokenStorage.clearToken();
    FlutterBackgroundService().invoke('stop');
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/qr-scanner');
    }
  }

  Future<void> _showRenameDialog(Map<String, dynamic> device) async {
    final controller = TextEditingController(text: device['name'] as String? ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1F2A),
        title: const Text('Rename device', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter new name...',
            hintStyle: TextStyle(color: Colors.white38),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Rename', style: TextStyle(color: Colors.cyan)),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      final uid = device['uid'] as String?;
      if (uid != null) {
        DeviceWS().sendCommand('rename_device', data: {
          'device_uid': uid,
          'new_name': newName,
        });
      }
    }
  }

  void _showSelfDeleteWarning() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1F2A),
        title: const Text('Cannot Delete', style: TextStyle(color: Colors.white)),
        content: const Text(
          "Can't delete active device, go the Admin dashboard or use logout to remove this device",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Colors.cyan)),
          ),
        ],
      ),
    );
  }

  Future<bool> _showDeleteConfirmDialog(Map<String, dynamic> device) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1F2A),
        title: const Text('Delete device', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete ${device['name'] ?? 'Unknown'}?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (result == true) {
      final uid = device['uid'] as String?;
      if (uid != null) {
        DeviceWS().sendCommand('delete_device', data: {'device_uid': uid});
      }
    }
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tabIndex == 0) {
      return _buildDashboardTab();
    } else {
      return _buildDevicesTab();
    }
  }

  Widget _buildDashboardTab() {
    final selfDevice = _devices.firstWhere(
      (d) => d['uid'] == _selfDeviceUid,
      orElse: () => <String, dynamic>{},
    );
    final deviceName = selfDevice['name'] as String? ?? 'This Device';
    final deviceType = selfDevice['type'] as String? ?? 'Phone';

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                // ── Server Card ──
                _StatusCard(
                  icon: Icons.dns,
                  title: 'SERVER STATUS',
                  status: serverStatus,
                  subtitle: 'Connected to N.I.X Server',
                  pingMs: _pingMs,
                  pinging: _pinging,
                  button: CustomButton(
                    onPressed: _refreshConnection,
                    text: 'Refresh',
                    backgroundColor: Colors.cyan,
                    icon: Icons.refresh,
                  ),
                ),
                const SizedBox(height: 16),
                // ── Device Card ──
                _StatusCard(
                  icon: Icons.phone_android,
                  title: 'DEVICE STATUS',
                  status: deviceStatus,
                  subtitle: '$deviceName \u2014 $deviceType',
                  button: CustomButton(
                    onPressed: _changeDeviceStatus,
                    text: deviceStatus == 'Online' ? 'Go Offline' : 'Go Online',
                    backgroundColor: deviceStatus == 'Online'
                        ? Colors.red
                        : Colors.lightGreen,
                    icon: deviceStatus == 'Online'
                        ? Icons.offline_bolt
                        : Icons.online_prediction,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDevicesTab() {
    if (_devices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices, color: Colors.white38, size: 64),
            const SizedBox(height: 16),
            Text(
              'No devices registered',
              style: TextStyle(color: Colors.white38, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _devices.length,
      itemBuilder: (context, i) {
        final d = _devices[i];
        final isOnline = d['is_online'] as bool? ?? false;
        final isActive = d['is_active'] as bool? ?? true;
        final online = isActive && isOnline;

        return Dismissible(
          key: ValueKey(d['uid']),
          direction: DismissDirection.horizontal,
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              if (d['uid'] == _selfDeviceUid) {
                _showSelfDeleteWarning();
                return false;
              }
              return await _showDeleteConfirmDialog(d);
            } else {
              await _showRenameDialog(d);
              return false;
            }
          },
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.edit, color: Colors.green),
          ),
          secondaryBackground: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.delete, color: Colors.red),
          ),
          child: Card(
            color: AppColors.cardBackground,
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              leading: Icon(
                Icons.phone_android,
                color: online ? Colors.green : Colors.redAccent,
              ),
              title: Text(
                d['name'] as String? ?? 'Unknown',
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                '${d['type'] ?? 'N/A'} \u2014 ${online ? 'Online' : 'Offline'}',
                style: TextStyle(
                  color: online ? Colors.green : Colors.redAccent,
                  fontSize: 12,
                ),
              ),
              trailing: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: online ? Colors.green : Colors.redAccent,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String status;
  final String subtitle;
  final Widget button;
  final int? pingMs;
  final bool pinging;

  const _StatusCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.subtitle,
    required this.button,
    this.pingMs,
    this.pinging = false,
  });

  @override
  Widget build(BuildContext context) {
    final isOnline = status == 'Online';
    final pingText = pinging
        ? 'Pinging...'
        : pingMs != null
            ? '${pingMs}ms'
            : '\u2014';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline ? Colors.green.withValues(alpha: 0.3) : Colors.redAccent.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: isOnline ? Colors.green : Colors.redAccent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOnline ? Colors.green : Colors.redAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isOnline ? Colors.green : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[400],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Icon(Icons.wifi_tethering, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  'Ping: ',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
                Text(
                  pingText,
                  style: TextStyle(
                    fontSize: 12,
                    color: pingMs != null ? Colors.green : Colors.grey[500],
                    fontWeight: pingMs != null ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: button),
        ],
      ),
    );
  }
}
