# N.I.X-App — Agent Guide

Flutter (Dart) client for N.I.X. See root `AGENTS.md` for cross-project context.

## Commands

```sh
flutter pub get              # install dependencies
flutter analyze              # lint + typecheck
flutter build apk --release  # build Android APK
```

Lint: `avoid_print: false`, `prefer_single_quotes: true` (in `analysis_options.yaml`).

### Dependencies

Key packages added: `flutter_svg` (^2.0.17) for SVG rendering in AppBar header.

## Architecture

- **State management**: None — uses `setState()` on `StatefulWidget`s + static storage singletons (`AppDataStorage`, `TokenStorage`)
- **API layer**: Top-level async functions in `lib/api/` — not classes
- **Routing**: Named routes `/home` and `/dashboard` + `Navigator.push` for Login, Registration, QRScanner
- **Storage**: `SharedPreferences` (token, device status) + JSON file (`login_data.json`) via `path_provider`

## Key files

| File | Role |
|------|------|
| `lib/main.dart` | Entrypoint, `SplashScreen`, route table, background service init, notification method channel handler, WS status → notification subtitle sync |
| `lib/utils/auto_update.dart` | Auto-update check trigger — calls `UpdateService.startAutoCheck()` only after device registration; listens to `onUpdateAvailable` stream and shows native notification |
| `lib/utils/app_navigation.dart` | Static callback holder for notification tap → Dev/Updates tab navigation |
| `lib/services/update_service.dart` | GitHub release checker + downloader via `open_filex`; 24hr auto-check timer via `startAutoCheck(version)`, `onUpdateAvailable` stream for auto-found updates. Downloads to `{externalStorageDir}/Download/nix-{tag}.apk` with PK magic byte integrity check |
| `lib/screens/home_screen.dart` | Main UI with sliding selector (Stats, Message, SysLogs, Dev); hexagon SVG logo in AppBar; handles notification tap → Dev/Updates |
| `lib/screens/login_screen.dart` | Email + Password + 2FA OTP login form |
| `lib/screens/registration_screen.dart` | Registration form (**stub** — not implemented) |
| `lib/screens/qr_scanner_screen.dart` | QR scanner for device registration with JWT verification; triggers auto-update check on success |
| `lib/screens/dashboard_screen.dart` | Control Center: server/device status, toggle, logout |
| `lib/api/login.dart` | `POST /api/v1/user/auth/login` |
| `lib/api/register_device.dart` | `POST /api/v1/device/manage/add-device` |
| `lib/api/logout_device.dart` | `POST /api/v1/device/manage/logout` |
| `lib/api/notification_email.dart` | `PUT /api/v1/user/preferences/notification-email` |
| `lib/services/device_ws.dart` | Persistent WS connection to `/ws/device/{uid}/{did}` with auto-reconnect; `onConnectionChange` callback for status sync |
| `lib/widgets/dev_panel.dart` | Developer panel: update checks, settings, email prefs, bg service toggle, logout (routes to `/qr-scanner`, stops bg service) |
| `lib/widgets/stats_panel.dart` | Dashboard stats: Server/Device status cards with ping display, device list, force logout handler |
| `lib/utils/appdata_storage.dart` | Login data (JSON + SharedPreferences), preferences (notification email, background run, dev unlock) |
| `lib/utils/token_storage.dart` | JWT token storage (SharedPreferences) |
| `lib/utils/app_constants.dart` | Server URL, WS URL, dev password, notification channel IDs (`notificationChannelId`, `updateNotificationChannelId`) |
| `lib/utils/app_colors.dart` | Dark theme constants |
| `lib/utils/responsive.dart` | Screen-size-aware layout helpers |

## Key flows

- **Auth**: SplashScreen → `isLoggedIn()` → `/dashboard` or `/home` → LoginScreen → QRScannerScreen → DashboardScreen
- **WebSocket**: `DeviceWS` singleton — auto-reconnects, pushes status updates, handles `logout` commands
- **Background service**: `FlutterBackgroundService` foreground service (Android) — started on app launch, togglable from Dev Panel Settings
- **Updates (manual)**: Dev Panel → fetches releases from `arman29-dev/N.I.X-App` (public GitHub API), downloads APK to `{externalStorageDir}/Download/nix-{tag}.apk`, verifies PK magic bytes, then installs via `open_filex` (inferring MIME from `.apk` extension). Android manifest declares `REQUEST_INSTALL_PACKAGES` permission for Android 8+ compatibility
- **Updates (auto)**: `UpdateService.startAutoCheck(version)` called from `lib/utils/auto_update.dart` — checks immediately on app start + every 24hrs via `Timer.periodic`; fires `onUpdateAvailable` stream when newer version found; `auto_update.dart` listens and calls `showUpdateNotification` via native MethodChannel (Android `NotificationCompat` notification with tap-to-open-updates intent). Only triggers *after* device registration — called from `SplashScreen._checkLoginStatus()` (logged-in path) and `QRScannerScreen._processQRData()` (on successful scan).
- **Update notification tap**: Android `PendingIntent` launches MainActivity with `nix_open_updates` extra → `onNewIntent`/cold start check invokes `openUpdates` on Flutter method channel → `AppNavigation.onOpenUpdates` callback switches HomeScreen to Dev panel Updates tab
- **Ping**: StatsPanel server card displays HTTP `GET /ping` round-trip latency (ms); measured on WS connect + manual Refresh; shown as `Ping: 24ms` or `Ping: —` if unavailable
- **Foreground notification status**: `_wireDeviceWSNotifications()` in `main.dart` registers `DeviceWS().onConnectionChange` callback; when WS connects/disconnects, updates foreground notification subtitle via `FlutterBackgroundService().invoke('updateNotification', {'status': 'running'|'idle'})`; also fires immediately on setup if WS already connected (race condition guard)
- **Logout (corrected)**: Dev Panel Settings → Logout → API call → disconnect WS → clear local data → stop background service → navigate to `/qr-scanner` (not `/dashboard`)
- **App icons**: N.I.X hexagon used across three Android resources — launcher icon (`ic_launcher_vector.xml`, adaptive via `mipmap-anydpi-v26/ic_launcher.xml` with dark `#0D1117` background), notification icon (`ic_notification.xml`), and foreground service notification override (`drawable-anydpi-v26/ic_bg_service_small.xml` which overrides `flutter_background_service_android`'s built-in leaf icon via resource priority). Header icon in HomeScreen uses `SvgPicture.asset` with `colorFilter: Colors.black` on the cyan AppBar background.

## Version management

- **App version** is read from `PackageInfo.fromPlatform().version` (maps to `pubspec.yaml` `version:` field at build time)
- **Installed release tracking**: After a successful APK install, the GitHub release tag (e.g. `v2.2.1`) is stored in SharedPreferences via `AppDataStorage.setLastInstalledRelease(tag)`. On subsequent update checks, if the latest GitHub release matches the stored tag, the update is suppressed — preventing infinite update loops when `pubspec.yaml` hasn't been bumped yet

## Known issues

- Registration API is a stub (`// TODO: Implement registration API call`)
- `launchers.dart` utility file is unused
- "Login with Passkey" and "Forgot Password" buttons have empty `onPressed`
- `register_device.dart` hardcodes WiFi interface `wlan0` (Android only)
- No token refresh mechanism — 30-day JWT expiry
- Server URL hardcoded in all API files and `device_ws.dart` — needs extraction to config

## Platform support

Configured for Android, iOS, macOS, Windows, Linux. Currently only tested on Android.
