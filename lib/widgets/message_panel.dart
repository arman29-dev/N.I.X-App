import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../services/device_ws.dart';
import '../api/upload_file.dart';
import '../utils/app_colors.dart';
import '../utils/appdata_storage.dart';
import '../utils/responsive.dart';

class MessagePanel extends StatefulWidget {
  final int tabIndex;
  final ValueChanged<int> onTabChanged;
  final ValueChanged<int>? onUnreadChanged;

  const MessagePanel({
    super.key,
    required this.tabIndex,
    required this.onTabChanged,
    this.onUnreadChanged,
  });

  @override
  State<MessagePanel> createState() => _MessagePanelState();
}

class _CmdEntry {
  final String cmd;
  final String desc;
  const _CmdEntry(this.cmd, this.desc);
}

class _MessagePanelState extends State<MessagePanel> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  StreamSubscription<Map<String, dynamic>>? _wsSub;

  String? _selectedDeviceUid;
  String? _selfDeviceUid;
  List<Map<String, dynamic>> _devices = [];

  // File upload state
  bool _attachPressed = false;
  bool _uploading = false;

  // File download state
  final Set<String> _downloadingFiles = {};
  final Map<String, double> _downloadProgress = {};
  StreamSubscription<double>? _downloadSub;

  // Unread message tracking
  int _unreadCount = 0;
  bool _isChatTabVisible = false;

  // Terminal state
  final TextEditingController _terminalController = TextEditingController();
  final ScrollController _terminalScrollController = ScrollController();
  final FocusNode _terminalFocusNode = FocusNode();
  final List<String> _terminalLines = [];
  bool _showTerminalWarning = false;
  bool _showSuggestions = false;
  List<_CmdEntry> _filteredCommands = [];
  int _selectedSuggestionIndex = -1;

  static const _cmdList = [
    _CmdEntry('help', 'Show available commands'),
    _CmdEntry('clear', 'Clear terminal'),
    _CmdEntry('status', 'Show connection status'),
    _CmdEntry('devices', 'List connected devices'),
    _CmdEntry('echo', 'Echo text back'),
    _CmdEntry('ws', 'Send raw WS message'),
  ];

  @override
  void initState() {
    super.initState();
    _terminalController.addListener(_onTerminalTextChanged);
    _terminalFocusNode.addListener(_onTerminalFocusChanged);
    _loadSelfDeviceUid();
  }

  Future<void> _loadSelfDeviceUid() async {
    final uid = await AppDataStorage.getDeviceUID();
    if (!mounted) return;
    _selfDeviceUid = uid;
    _connectWS();
    _requestDevices();
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
          final isFromSelf = from == _selfDeviceUid;
          setState(() {
            _messages.add({
              'from': from,
              'text': text,
              'time': DateTime.now().toIso8601String(),
            });
          });
          _scrollToBottom();
          if (!isFromSelf && !_isChatTabVisible) {
            _unreadCount++;
            widget.onUnreadChanged?.call(_unreadCount);
            _showMessageNotification(from, text);
          }
        }
      } else if (event == 'file_message') {
        final data = msg['data'] as Map<String, dynamic>?;
        if (data != null) {
          final fileId = data['file_id'] as String? ?? '';
          final fromDevice = data['from_device'] as String? ?? 'server';
          // Skip if this file_id is already in messages (e.g., sent by self)
          final alreadyExists = _messages.any(
            (m) => m['type'] == 'file' && m['file_id'] == fileId,
          );
          if (!alreadyExists) {
            setState(() {
              _messages.add({
                'type': 'file',
                'file_id': fileId,
                'file_name': data['file_name'],
                'file_size': data['file_size'],
                'mime_type': data['mime_type'],
                'from': fromDevice,
                'time': DateTime.now().toIso8601String(),
              });
            });
            _scrollToBottom();
          }
          // Show notification only for files from other devices
          if (fromDevice != _selfDeviceUid && !alreadyExists) {
            _showFileNotification(
              data['file_name'] as String? ?? 'File',
              data['file_size'] as int? ?? 0,
            );
          }
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

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      withData: false,
      withReadStream: false,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final path = file.path;
    if (path == null) return;

    final fileName = file.name;
    final fileSize = file.size;
    if (fileSize > 512 * 1024 * 1024) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File too large (max 512MB)'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() => _uploading = true);

    try {
      final fileId = await uploadFile(path, fileName, targetDevice: _selectedDeviceUid);
      if (fileId == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Upload failed - check connection and try again'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _downloadFile(String fileId, String fileName) async {
    if (_downloadingFiles.contains(fileId)) return;

    final dir = await getApplicationDocumentsDirectory();
    final savePath = '${dir.path}/$fileName';

    setState(() {
      _downloadingFiles.add(fileId);
      _downloadProgress[fileId] = 0.0;
    });

    final progressStream = downloadFileWithProgress(fileId, savePath);
    _downloadSub = progressStream.listen((progress) {
      if (!mounted) return;
      if (progress < 0) {
        setState(() {
          _downloadingFiles.remove(fileId);
          _downloadProgress.remove(fileId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download failed'),
            duration: Duration(seconds: 2),
          ),
        );
      } else if (progress >= 1.0) {
        setState(() {
          _downloadingFiles.remove(fileId);
          _downloadProgress.remove(fileId);
        });
        OpenFilex.open(savePath);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opened $fileName'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        setState(() => _downloadProgress[fileId] = progress);
      }
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _showFileNotification(String fileName, int fileSize) {
    const channel = MethodChannel('nix/notifications');
    final sizeStr = _formatFileSize(fileSize);
    channel.invokeMethod('showFileNotification', {
      'file_name': fileName,
      'file_size': sizeStr,
    });
  }

  void _showMessageNotification(String senderName, String message) {
    const channel = MethodChannel('nix/notifications');
    channel.invokeMethod('showMessageNotification', {
      'sender_name': senderName,
      'message': message,
    });
  }

  void _sendTerminalCommand() {
    final cmd = _terminalController.text.trim();
    if (cmd.isEmpty) return;

    setState(() {
      _terminalLines.add('> $cmd');
      _showSuggestions = false;
      _filteredCommands = [];
      _selectedSuggestionIndex = -1;
    });

    DeviceWS().sendCommand('terminal_exec', data: {'command': cmd});
    _terminalController.clear();
    _scrollTerminalToBottom();
  }

  void _insertSuggestion(String cmd) {
    _terminalController.text = '/$cmd';
    _terminalController.selection = TextSelection.fromPosition(
      TextPosition(offset: _terminalController.text.length),
    );
    setState(() {
      _showSuggestions = false;
      _filteredCommands = [];
      _selectedSuggestionIndex = -1;
    });
  }

  void _dismissSuggestions() {
    setState(() {
      _showSuggestions = false;
      _filteredCommands = [];
      _selectedSuggestionIndex = -1;
    });
  }

  void _onTerminalFocusChanged() {
    if (!_terminalFocusNode.hasFocus) {
      _dismissSuggestions();
    }
  }

  void _onTerminalTextChanged() {
    final text = _terminalController.text;
    final showWarning = text.isNotEmpty && !text.startsWith('/');
    if (showWarning != _showTerminalWarning && mounted) {
      setState(() => _showTerminalWarning = showWarning);
    }
    // command suggestions
    if (text.startsWith('/')) {
      final partial = text.substring(1).toLowerCase();
      final filtered = partial.isEmpty
          ? _cmdList.toList()
          : _cmdList.where((e) => e.cmd.startsWith(partial)).toList();
      if (mounted) {
        setState(() {
          _filteredCommands = filtered;
          _showSuggestions = filtered.isNotEmpty;
          _selectedSuggestionIndex = filtered.isNotEmpty ? 0 : -1;
        });
      }
    } else if (_showSuggestions && mounted) {
      setState(() {
        _showSuggestions = false;
        _filteredCommands = [];
        _selectedSuggestionIndex = -1;
      });
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
    _downloadSub?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    _terminalController.removeListener(_onTerminalTextChanged);
    _terminalController.dispose();
    _terminalFocusNode.removeListener(_onTerminalFocusChanged);
    _terminalFocusNode.dispose();
    _terminalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isChat = widget.tabIndex == 0;
    if (isChat && !_isChatTabVisible) {
      _isChatTabVisible = true;
      if (_unreadCount > 0) {
        _unreadCount = 0;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onUnreadChanged?.call(0);
        });
      }
    } else if (!isChat) {
      _isChatTabVisible = false;
    }
    if (isChat) {
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
                    final isFile = msg['type'] == 'file';
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
                        child: isFile
                            ? _buildFileBubble(msg, isMe)
                            : Text(
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
                if (_uploading)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.cyan,
                      ),
                    ),
                  ),
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
                const SizedBox(width: 4),
                GestureDetector(
                  onTapDown: (_) => setState(() => _attachPressed = true),
                  onTapUp: (_) {
                    setState(() => _attachPressed = false);
                    _pickAndUploadFile();
                  },
                  onTapCancel: () =>
                      setState(() => _attachPressed = false),
                  child: AnimatedScale(
                    scale: _attachPressed ? 0.85 : 1.0,
                    duration: const Duration(milliseconds: 100),
                    child: Icon(
                      Icons.attach_file,
                      color: Colors.cyan,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
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

  Widget _buildFileBubble(Map<String, dynamic> msg, bool isMe) {
    final fileName = msg['file_name'] as String? ?? 'file';
    final fileSize = msg['file_size'] as int? ?? 0;
    final fileId = msg['file_id'] as String? ?? '';
    final isDownloading = _downloadingFiles.contains(fileId);
    final progress = _downloadProgress[fileId] ?? 0.0;

    return GestureDetector(
      onTap: () {
        if (fileId.isNotEmpty && !isDownloading) {
          _downloadFile(fileId, fileName);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Icon(
                Icons.insert_drive_file,
                color: isDownloading ? Colors.white38 : (isMe ? Colors.white : Colors.cyan),
                size: 28,
              ),
              if (isDownloading)
                Positioned.fill(
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 2.5,
                        color: Colors.cyan,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    color: isDownloading
                        ? Colors.white38
                        : (isMe ? Colors.white : Colors.cyan),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  isDownloading
                      ? 'Downloading ${(progress * 100).toStringAsFixed(0)}%'
                      : _formatFileSize(fileSize),
                  style: TextStyle(
                    color: isDownloading ? Colors.cyan : (isMe ? Colors.white60 : Colors.white38),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
        // ── Command Suggestions ──
        AnimatedSize(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          alignment: Alignment.bottomCenter,
          child: _showSuggestions && _filteredCommands.isNotEmpty
              ? Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0A0A),
                    border: Border(
                      top: BorderSide(color: Colors.white12),
                      bottom: BorderSide(color: Colors.white12),
                    ),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _filteredCommands.length,
                    itemBuilder: (context, i) {
                      final entry = _filteredCommands[i];
                      final selected = i == _selectedSuggestionIndex;
                      return InkWell(
                        onTap: () => _insertSuggestion(entry.cmd),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          color: selected
                              ? const Color(0xFF1C1F2A)
                              : Colors.transparent,
                          child: Row(
                            children: [
                              Text(
                                '/${entry.cmd}',
                                style: const TextStyle(
                                  color: Colors.cyan,
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                entry.desc,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                )
              : const SizedBox.shrink(),
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
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent || event is KeyRepeatEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.escape) {
                    if (_showSuggestions) {
                      _dismissSuggestions();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  }
                  if (!_showSuggestions || _filteredCommands.isEmpty) {
                    return KeyEventResult.ignored;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    setState(() {
                      _selectedSuggestionIndex = (_selectedSuggestionIndex + 1) % _filteredCommands.length;
                    });
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    setState(() {
                      _selectedSuggestionIndex = (_selectedSuggestionIndex - 1 + _filteredCommands.length) % _filteredCommands.length;
                    });
                    return KeyEventResult.handled;
                  }
                  if (event.logicalKey == LogicalKeyboardKey.enter && _selectedSuggestionIndex >= 0) {
                    _insertSuggestion(_filteredCommands[_selectedSuggestionIndex].cmd);
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: Row(
                children: [
                  const Icon(Icons.chevron_right, color: Colors.green, size: 18),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      focusNode: _terminalFocusNode,
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
                    onEditingComplete: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ],
    );
  }
}
