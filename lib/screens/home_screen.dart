import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import '../widgets/sliding_selector.dart';
import '../widgets/stats_panel.dart';
import '../widgets/message_panel.dart';
import '../widgets/syslogs_panel.dart';
import '../widgets/dev_panel.dart';
import '../utils/app_navigation.dart';
import '../utils/app_colors.dart';
import '../utils/appdata_storage.dart';

List<SectionData> _sections = const [
  SectionData(label: 'Stats', icon: Icons.dashboard, activeColor: Color(0xFF1DB954)),
  SectionData(label: 'Message', icon: Icons.terminal, activeColor: Color(0xFF4ECDC4)),
  SectionData(label: 'SysLogs', icon: Icons.receipt_long, activeColor: Color(0xFF42A5F5)),
  SectionData(label: 'Dev', icon: Icons.code, activeColor: Color(0xFFFFA726)),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _currentTab = 0;
  final ValueNotifier<int> _devTabController = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBatteryOptimization();
    });
    AppNavigation.onOpenUpdates = _openDevUpdatesTab;
    if (AppNavigation.pendingOpenUpdates) {
      AppNavigation.pendingOpenUpdates = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openDevUpdatesTab());
    }
  }

  @override
  void dispose() {
    AppNavigation.onOpenUpdates = null;
    _devTabController.dispose();
    super.dispose();
  }

  void _openDevUpdatesTab() {
    setState(() {
      _selectedIndex = 3;
      _currentTab = 0;
    });
    _devTabController.value = 0;
  }

  Future<void> _checkBatteryOptimization() async {
    if (!Platform.isAndroid) return;
    final alreadyAsked = await AppDataStorage.getBatteryOptAsked();
    if (alreadyAsked) return;
    await AppDataStorage.setBatteryOptAsked(true);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1F2A),
        title: const Text('Background Connection', style: TextStyle(color: Colors.white)),
        content: const Text(
          'N.I.X needs to run in the background to stay connected.\n\nPlease disable battery optimization for this app.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Skip', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _openBatteryOptimizationSettings();
            },
            child: const Text('Open Settings', style: TextStyle(color: Colors.cyan)),
          ),
        ],
      ),
    );
  }

  Future<void> _openBatteryOptimizationSettings() async {
    const platform = MethodChannel('nix/battery_optimization');
    try {
      await platform.invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      debugPrint('Battery optimization: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDev = _selectedIndex == 3;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/images/nix_logo.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                Colors.black,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 8),
            const Text('N.I.X'),
          ],
        ),
        backgroundColor: AppColors.accent,
        centerTitle: true,
      ),
      body: Column(
        children: [
          SlidingSelector(
            selectedIndex: _selectedIndex,
            onChanged: (i) {
              setState(() {
                _selectedIndex = i;
                _currentTab = 0;
              });
            },
            sections: _sections,
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                StatsPanel(tabIndex: _currentTab, onTabChanged: _onTabChanged),
                MessagePanel(tabIndex: _currentTab, onTabChanged: _onTabChanged),
                SysLogsPanel(tabIndex: _currentTab, onTabChanged: _onTabChanged),
                DevPanel(devTabController: _devTabController),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDev
          ? null
          : _buildBottomNav(),
    );
  }

  void _onTabChanged(int tab) {
    setState(() => _currentTab = tab);
  }

  Widget _buildBottomNav() {
    List<BottomNavigationBarItem> items;
    switch (_selectedIndex) {
      case 0:
        items = const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.devices), label: 'Devices'),
        ];
        break;
      case 1:
        items = const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.terminal), label: 'Terminal'),
        ];
        break;
      case 2:
        items = const [
          BottomNavigationBarItem(icon: Icon(Icons.dns), label: 'Server'),
          BottomNavigationBarItem(icon: Icon(Icons.phone_android), label: 'Device'),
        ];
        break;
      default:
        items = const [];
    }

    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: const Color(0xFF1C1F2A),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: _onTabChanged,
        items: items,
        selectedItemColor: _sections[_selectedIndex].activeColor,
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
