import 'package:flutter/material.dart';

typedef NavigationCallback = void Function();

class AppNavigation {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static NavigationCallback? onOpenUpdates;
  static bool pendingOpenUpdates = false;
  static NavigationCallback? onOpenChat;
  static bool pendingOpenChat = false;
  static NavigationCallback? onOpenDevPanel;
}
