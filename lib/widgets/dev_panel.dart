import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../services/update_service.dart';
import '../services/device_ws.dart';
import '../api/logout_device.dart';
import '../api/notification_email.dart';
import '../utils/app_constants.dart';
import '../utils/appdata_storage.dart';
import '../utils/app_colors.dart';
import '../utils/token_storage.dart';

class DevPanel extends StatefulWidget {
  const DevPanel({super.key});

  @override
  State<DevPanel> createState() => _DevPanelState();
}

class _DevPanelState extends State<DevPanel> {
  final TextEditingController _passwordController = TextEditingController();
  bool _unlocked = false;
  bool _passwordError = false;
  bool _obscurePassword = true;

  String _currentVersion = '0.0.0';
  String? _latestVersion;
  String? _releaseBody;
  String? _releaseUrl;
  bool _checking = false;
  bool _checkFailed = false;
  bool _hasUpdate = false;
  List<dynamic>? _releaseAssets;
  bool _downloading = false;
  double _downloadProgress = 0;
  String? _downloadStatus;
  StreamSubscription<double>? _progressSub;

  @override
  void dispose() {
    _passwordController.dispose();
    _emailController.dispose();
    _progressSub?.cancel();
    super.dispose();
  }

  void _unlock() {
    final pwd = _passwordController.text.trim();
    if (pwd == AppConstants.devPassword) {
      setState(() {
        _unlocked = true;
        _passwordError = false;
      });
      AppDataStorage.setDevUnlocked(true);
      _initAndCheck();
    } else {
      setState(() => _passwordError = true);
    }
  }

  Future<void> _restoreUnlocked() async {
    final unlocked = await AppDataStorage.getDevUnlocked();
    if (mounted && unlocked) {
      setState(() => _unlocked = true);
      _initAndCheck();
    }
  }

  Future<void> _initAndCheck() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _currentVersion = info.version);
    }
    _checkForUpdate();
  }

  void _lock() {
    AppDataStorage.setDevUnlocked(false);
    setState(() {
      _unlocked = false;
      _passwordController.clear();
      _passwordError = false;
      _latestVersion = null;
      _releaseBody = null;
      _releaseUrl = null;
      _releaseAssets = null;
      _hasUpdate = false;
      _checkFailed = false;
      _downloadStatus = null;
      _downloadProgress = 0;
    });
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _checking = true;
      _checkFailed = false;
    });
    final release = await UpdateService().checkForUpdate();
    if (mounted) {
      setState(() {
        _checking = false;
        if (release != null) {
          _latestVersion = release['tag_name'] as String?;
          _releaseBody = release['body'] as String?;
          _releaseUrl = release['html_url'] as String?;
          _releaseAssets = release['assets'] as List<dynamic>?;
          _hasUpdate = _compareVersions(
            _latestVersion ?? '',
            _currentVersion,
          );
        } else {
          _checkFailed = true;
        }
      });
    }
  }

  bool _compareVersions(String latest, String current) {
    final a = latest.replaceFirst(RegExp(r'^v'), '');
    final b = current.replaceFirst(RegExp(r'^v'), '');
    if (a.isEmpty || b.isEmpty) return false;
    final partsA = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final partsB = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < partsA.length && i < partsB.length; i++) {
      if (partsA[i] > partsB[i]) return true;
      if (partsA[i] < partsB[i]) return false;
    }
    return partsA.length > partsB.length;
  }

  void _downloadUpdate() {
    final release = {
      'tag_name': _latestVersion,
      'body': _releaseBody,
      'html_url': _releaseUrl,
      'assets': _releaseAssets,
    };

    setState(() {
      _downloading = true;
      _downloadStatus = 'Downloading...';
    });

    _progressSub = UpdateService().progressStream.listen((progress) {
      if (mounted) {
        setState(() => _downloadProgress = progress);
      }
    });

    UpdateService().downloadAndInstall(release).then((_) {
      if (mounted) {
        setState(() {
          _downloading = false;
          _downloadProgress = 1.0;
          _downloadStatus = 'Download complete! Installing...';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) {
      return _buildLockedState();
    }
    return _buildUnlockedState();
  }

  Widget _buildLockedState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, color: Colors.white24, size: 48),
            const SizedBox(height: 20),
            Text(
              'Developer Panel',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter password',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF1C1F2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: _passwordError
                      ? const BorderSide(color: Colors.redAccent)
                      : BorderSide.none,
                ),
                errorText: _passwordError ? 'Incorrect password' : null,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white38,
                    size: 20,
                  ),
                ),
              ),
              onSubmitted: (_) => _unlock(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _unlock,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Unlock'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _devTabIndex = 0;
  final TextEditingController _emailController = TextEditingController();
  bool _backgroundRun = false;

  @override
  void initState() {
    super.initState();
    _restoreUnlocked();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final email = await AppDataStorage.getNotificationEmail();
    final bgRun = await AppDataStorage.getBackgroundRun();
    if (mounted) {
      setState(() {
        _emailController.text = email ?? '';
        _backgroundRun = bgRun;
      });
    }
  }

  Widget _buildUnlockedState() {
    return Column(
      children: [
        Expanded(
          child: IndexedStack(
            index: _devTabIndex,
            children: [
              _buildUpdatesTab(),
              _buildSettingsTab(),
            ],
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.white12, width: 0.5),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _devTabIndex,
            onTap: (i) => setState(() => _devTabIndex = i),
            backgroundColor: const Color(0xFF1C1F2A),
            selectedItemColor: Colors.amber,
            unselectedItemColor: Colors.white38,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.system_update), label: 'Updates'),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpdatesTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBodyHeight = constraints.maxHeight * 0.45;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.white54, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'CURRENT VERSION',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'v$_currentVersion',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_checking)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.amber,
                              strokeWidth: 2,
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: _checkForUpdate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.refresh, size: 12, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Check for Update',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (_hasUpdate)
                _buildUpdateResultCard(maxBodyHeight: maxBodyHeight)
              else if (!_checking && _latestVersion != null && !_hasUpdate)
                _buildUpToDateCard(),

              if (_checking && _latestVersion == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2),
                  ),
                ),

              if (_checkFailed)
                _buildCheckFailedCard(),

              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _lock,
                  icon: const Icon(Icons.lock, size: 18),
                  label: const Text('Lock Developer Panel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Notification email card
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notification Email',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter notification email',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: const Color(0xFF2A2D3A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: _saveNotificationEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Save', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Background run card
          _SectionCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Background Connection',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Run as foreground service',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _backgroundRun,
                  onChanged: _toggleBackgroundRun,
                  activeTrackColor: Colors.cyan,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Logout + Lock card
          _SectionCard(
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Logout', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _lock,
                    icon: const Icon(Icons.lock, size: 18),
                    label: const Text('Lock Developer Panel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _saveNotificationEmail() async {
    final email = _emailController.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    final success = await updateNotificationEmail(email);
    if (mounted) {
      if (success) {
        await AppDataStorage.setNotificationEmail(email);
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Notification email saved'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Failed to save notification email'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _toggleBackgroundRun(bool value) async {
    setState(() => _backgroundRun = value);
    await AppDataStorage.setBackgroundRun(value);
    if (value) {
      await FlutterBackgroundService().startService();
    } else {
      FlutterBackgroundService().invoke('stop');
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1F2A),
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to logout this device?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await logout();
              } catch (_) {}
              await DeviceWS().disconnect();
              await AppDataStorage.clearAppData();
              await TokenStorage.clearToken();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/dashboard');
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildUpToDateCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check, color: Colors.green, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            'App is up to date',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckFailedCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.cloud_off, color: Colors.orange, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Could not check for updates',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: _checkForUpdate,
            child: const Text('Retry', style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateResultCard({double? maxBodyHeight}) {
    final bodyMaxHeight = (maxBodyHeight ?? 250.0).clamp(150.0, double.infinity);
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UPDATE AVAILABLE',
            style: TextStyle(
              color: Colors.amber,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _latestVersion!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_releaseBody != null && _releaseBody!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: BoxConstraints(maxHeight: bodyMaxHeight),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Markdown(
                  data: _releaseBody!,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
                    h1: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    h2: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    h3: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    listBullet: const TextStyle(color: Colors.white38),
                    code: const TextStyle(color: Colors.amber, fontSize: 12),
                    codeblockDecoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    a: const TextStyle(color: Colors.cyanAccent),
                    blockquoteDecoration: BoxDecoration(
                      border: Border(left: BorderSide(color: Colors.white24, width: 3)),
                    ),
                  ),
                ),
              ),
            ],
          if (_downloading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _downloadProgress,
              backgroundColor: Colors.white12,
              color: Colors.amber,
            ),
            const SizedBox(height: 4),
            Text(
              '${(_downloadProgress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
          if (_downloadStatus != null) ...[
            const SizedBox(height: 8),
            Text(
              _downloadStatus!,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (!_downloading)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _downloadUpdate,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text(
                      'Download & Install',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              if (_releaseUrl != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse(_releaseUrl!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text(
                      'View on GitHub',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }
}
