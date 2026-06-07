import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/log_service.dart';
import '../utils/app_colors.dart';

class SysLogsPanel extends StatefulWidget {
  final int tabIndex;
  final ValueChanged<int> onTabChanged;

  const SysLogsPanel({
    super.key,
    required this.tabIndex,
    required this.onTabChanged,
  });

  @override
  State<SysLogsPanel> createState() => _SysLogsPanelState();
}

class _SysLogsPanelState extends State<SysLogsPanel> {
  final LogService _logService = LogService();

  List<Map<String, dynamic>> _serverLogs = [];
  List<Map<String, dynamic>> _deviceLogs = [];
  bool _loading = false;
  String _activeLogType = 'server';

  @override
  void initState() {
    super.initState();
    _loadDeviceLogs();
  }

  void _loadDeviceLogs() {
    _logService.logStream.listen((entry) {
      if (!mounted) return;
      setState(() {
        _deviceLogs.insert(0, entry);
        if (_deviceLogs.length > 1000) {
          _deviceLogs = _deviceLogs.sublist(0, 500);
        }
      });
    });
  }

  Future<void> _fetchServerLogs(String logType) async {
    setState(() {
      _loading = true;
      _activeLogType = logType;
    });
    final logs = await _logService.fetchServerLogs(logType, lines: 200);
    if (mounted) {
      setState(() {
        _serverLogs = logs.reversed.toList();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tabIndex == 0) {
      return _buildServerLogsTab();
    } else {
      return _buildDeviceLogsTab();
    }
  }

  Widget _buildServerLogsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _logTypeChip('server', Colors.blue),
                const SizedBox(width: 8),
                _logTypeChip('security', Colors.orange),
                const SizedBox(width: 8),
                _logTypeChip('errors', Colors.red),
              ],
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _serverLogs.isEmpty
                  ? Center(
                      child: Text(
                        'Select a log type to view',
                        style: TextStyle(color: Colors.white38, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _serverLogs.length,
                      itemBuilder: (context, i) {
                        return _buildLogEntry(_serverLogs[i]);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _logTypeChip(String type, Color color) {
    final isActive = _activeLogType == type;
    return GestureDetector(
      onTap: () => _fetchServerLogs(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.25) : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? color : color.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          type.toUpperCase(),
          style: TextStyle(
            color: isActive ? color : Colors.white54,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> entry) {
    final level = entry['level'] as String? ?? '';
    final message = entry['message'] as String? ?? '';
    final timestamp = entry['timestamp'] as String? ?? '';

    Color levelColor;
    switch (level) {
      case 'ERROR':
        levelColor = Colors.redAccent;
        break;
      case 'WARNING':
        levelColor = Colors.orange;
        break;
      default:
        levelColor = Colors.white70;
    }

    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(
          text: '$timestamp $level $message',
        ));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log copied'), duration: Duration(seconds: 1)),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.cardBackground.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (timestamp.isNotEmpty)
              Text(
                timestamp,
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (level.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: levelColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      level,
                      style: TextStyle(color: levelColor, fontSize: 10),
                    ),
                  ),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: levelColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceLogsTab() {
    return _deviceLogs.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.terminal, color: Colors.white38, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Device logs will appear here',
                  style: TextStyle(color: Colors.white38, fontSize: 16),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _deviceLogs.length,
            itemBuilder: (context, i) {
              final entry = _deviceLogs[i];
              return GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(
                    text: entry['message'] as String? ?? '',
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Log copied'), duration: Duration(seconds: 1)),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry['level'] == 'ERROR' ? '\u2717' : '\u2192',
                        style: TextStyle(
                          color: entry['level'] == 'ERROR'
                              ? Colors.redAccent
                              : Colors.cyan,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          entry['message'] as String? ?? '',
                          style: TextStyle(
                            color: entry['level'] == 'ERROR'
                                ? Colors.redAccent
                                : Colors.white70,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }
}
