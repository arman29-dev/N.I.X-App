import 'dart:async';
import 'package:flutter/material.dart';

import '../services/device_ws.dart';
import '../utils/app_colors.dart';
import '../utils/appdata_storage.dart';
import '../utils/responsive.dart';

class MessagePanel extends StatefulWidget {
  final int tabIndex;
  final ValueChanged<int> onTabChanged;

  const MessagePanel({
    super.key,
    required this.tabIndex,
    required this.onTabChanged,
  });

  @override
  State<MessagePanel> createState() => _MessagePanelState();
}

class _MessagePanelState extends State<MessagePanel> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  String? _selectedDeviceUid;
  String? _selfDeviceUid;
  List<Map<String, dynamic>> _devices = [];

  // Terminal state
  final TextEditingController _terminalController = TextEditingController();
  final ScrollController _terminalScrollController = ScrollController();
  final List<String> _terminalLines = [];
  bool _showTerminalWarning = false;

  @override
  void initState() {
    super.initState();
    _connectWS();
    _requestDevices();
    _terminalController.addListener(_onTerminalTextChanged);
    AppDataStorage.getDeviceUID().then((uid) {
      _selfDeviceUid = uid;
    });
  }

  void _connectWS() {
    DeviceWS().connect();
    _wsSub = DeviceWS().messages.listen(_handleWSMessage);
  }

  void _requestDevices() {
    Future.delayed(const Duration(seconds: 2), () {
      if (DeviceWS().isConnected) {
        DeviceWS().sendCommand('get_devices');
      }
    });
  }

  void _handleWSMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;

    if (type == 'response') {
      final action = msg['action'] as String?;
      final data = msg['data'] as Map<String, dynamic>?;
      if (action == 'get_devices' && data != null) {
        final devices = data['devices'] as List<dynamic>?;
        if (devices != null) {
          setState(() {
            _devices = devices
                .cast<Map<String, dynamic>>()
                .where((d) => d['uid'] != _selfDeviceUid)
                .toList();
            if (_selectedDeviceUid == null && _devices.isNotEmpty) {
              _selectedDeviceUid = _devices[0]['uid'] as String?;
            } else if (_selectedDeviceUid != null &&
                !_devices.any((d) => d['uid'] == _selectedDeviceUid)) {
              _selectedDeviceUid =
                  _devices.isNotEmpty ? _devices[0]['uid'] as String? : null;
            }
          });
        }
        return;
      }
    }

    if (type == 'event') {
      final event = msg['event'] as String?;
      if (event == 'device_message') {
        final data = msg['data'] as Map<String, dynamic>?;
        if (data != null) {
          final text = data['message'] as String? ?? '';
          final from = data['from_device'] as String? ?? 'device';
          setState(() {
            _messages.add({
              'from': from,
              'text': text,
              'time': DateTime.now().toIso8601String(),
            });
          });
          _scrollToBottom();
        }
      } else if (event == 'cmd_output') {
        final data = msg['data'] as Map<String, dynamic>?;
        if (data != null) {
          final output = data['output'] as String? ?? '';
          final from = data['from_device'] as String? ?? 'device';
          setState(() {
            _terminalLines.add('[$from] $output');
            if (_terminalLines.length > 500) {
              _terminalLines.removeAt(0);
            }
          });
          _scrollTerminalToBottom();
        }
      }
    }
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    if (_selectedDeviceUid == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Select a device to send a message'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() {
      _messages.add({
        'from': 'Me',
        'text': text,
        'time': DateTime.now().toIso8601String(),
      });
    });

    DeviceWS().sendCommand('send_message', data: {
      'text': text,
      'target_device': _selectedDeviceUid,
    });
    _inputController.clear();
    _scrollToBottom();
  }

  void _sendTerminalCommand() {
    final cmd = _terminalController.text.trim();
    if (cmd.isEmpty) return;

    setState(() {
      _terminalLines.add('> $cmd');
    });

    DeviceWS().sendCommand('terminal_exec', data: {'command': cmd});
    _terminalController.clear();
    _scrollTerminalToBottom();
  }

  void _onTerminalTextChanged() {
    final text = _terminalController.text;
    final showWarning = text.isNotEmpty && !text.startsWith('/');
    if (showWarning != _showTerminalWarning && mounted) {
      setState(() => _showTerminalWarning = showWarning);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollTerminalToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_terminalScrollController.hasClients) {
        _terminalScrollController.animateTo(
          _terminalScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    _terminalController.removeListener(_onTerminalTextChanged);
    _terminalController.dispose();
    _terminalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tabIndex == 0) {
      return _buildChatTab();
    } else {
      return _buildTerminalTab();
    }
  }

  Widget _buildDeviceSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: const Color(0xFF1C1F2A),
      child: Row(
        children: [
          const Icon(Icons.devices, color: Colors.white38, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedDeviceUid,
                isExpanded: true,
                dropdownColor: const Color(0xFF1C1F2A),
                hint: const Text(
                  'Select device',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white38),
                items: _devices.map((d) {
                  final uid = d['uid'] as String? ?? '';
                  final name = d['name'] as String? ?? 'Unknown';
                  final online = d['is_online'] as bool? ?? false;
                  return DropdownMenuItem<String>(
                    value: uid,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: online ? Colors.green : Colors.redAccent,
                          ),
                        ),
                        Text(name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedDeviceUid = val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        if (_devices.isNotEmpty) _buildDeviceSelector(),
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Text(
                    'No messages yet',
                    style: TextStyle(color: Colors.white38, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, i) {
                    final msg = _messages[i];
                    final isMe = msg['from'] == 'Me';
                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.cyan.withValues(alpha: 0.2)
                              : AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        constraints: BoxConstraints(
                          maxWidth: Responsive.width(context) * 0.75,
                        ),
                        child: Text(
                          msg['text'] as String? ?? '',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1F2A),
            border: const Border(
              top: BorderSide(color: Colors.white12),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send, color: Colors.cyan),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTerminalTab() {
    return Column(
      children: [
        Expanded(
          child: Container(
            color: const Color(0xFF0A0A0A),
            child: _terminalLines.isEmpty
                ? Center(
                    child: Text(
                      'Terminal ready',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _terminalScrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _terminalLines.length,
                    itemBuilder: (context, i) {
                      final line = _terminalLines[i];
                      final isCommand = line.startsWith('>');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(
                          line,
                          style: TextStyle(
                            color: isCommand ? Colors.cyan : Colors.green,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
        Visibility(
          visible: _showTerminalWarning,
          maintainState: true,
          maintainAnimation: true,
          child: Container(
            color: Colors.orange.withValues(alpha: 0.15),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 14),
                const SizedBox(width: 6),
                const Text(
                  "Prefix commands with '/'",
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1F2A),
            border: const Border(
              top: BorderSide(color: Colors.white12),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                const Icon(Icons.chevron_right, color: Colors.green, size: 18),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _terminalController,
                    style: const TextStyle(
                      color: Colors.green,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter command...',
                      hintStyle: TextStyle(
                        color: Colors.white24,
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _sendTerminalCommand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
