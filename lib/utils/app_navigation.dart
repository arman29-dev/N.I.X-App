typedef NavigationCallback = void Function();

class AppNavigation {
  static NavigationCallback? onOpenUpdates;
  static bool pendingOpenUpdates = false;
}
