# N.I.X-App — Agent Guide

Flutter (Dart) client for N.I.X. See root `AGENTS.md` for cross-project context.

## Commands

```sh
flutter pub get              # install dependencies
flutter analyze              # lint + typecheck
flutter build apk --release  # build Android APK
```

Lint: `avoid_print: false`, `prefer_single_quotes: true` (in `analysis_options.yaml`).

## Architecture

- **State management**: None — `setState()` on `StatefulWidget`s + static storage singletons (`AppDataStorage`, `TokenStorage`)
- **API layer**: Top-level async functions in `lib/api/` — no classes
- **Routing**: Named routes `/home`, `/dashboard` + `Navigator.push` for Login, Registration, QRScanner
- **Storage**: `SharedPreferences` (token, device status, preferences) + JSON file (`login_data.json`) via `path_provider`

## Key files

| File | Role |
|------|------|
| `lib/main.dart` | Entrypoint, `SplashScreen`, route table, background service init |
| `lib/screens/home_screen.dart` | Main UI with sliding selector (Stats, Message, SysLogs, Dev) |
| `lib/screens/dashboard_screen.dart` | Control Center: server/device status, toggle, logout |
| `lib/screens/login_screen.dart` | Email + Password + 2FA OTP login form |
| `lib/screens/registration_screen.dart` | Registration form (**stub** — not implemented) |
| `lib/screens/qr_scanner_screen.dart` | QR scanner for device registration with JWT verification |
| `lib/api/login.dart` | `POST /api/v1/user/auth/login` |
| `lib/api/register_device.dart` | `POST /api/v1/device/manage/add-device` |
| `lib/api/logout_device.dart` | `POST /api/v1/device/manage/logout` |
| `lib/api/notification_email.dart` | `PUT /api/v1/user/preferences/notification-email` |
| `lib/services/device_ws.dart` | Persistent WS connection to `/ws/device/{uid}/{did}` with auto-reconnect; `onConnectionChange` callback for status sync |
| `lib/services/update_service.dart` | GitHub release checker + downloader via `open_filex` |
| `lib/widgets/dev_panel.dart` | Developer panel: update checks, settings, email prefs, bg service toggle, logout |
| `lib/widgets/stats_panel.dart` | Dashboard stats: Server/Device status cards, device list, force logout handler |
| `lib/utils/appdata_storage.dart` | Login data (JSON + SharedPreferences), preferences (notification email, background run, dev unlock) |
| `lib/utils/token_storage.dart` | JWT token storage (SharedPreferences) |
| `lib/utils/app_constants.dart` | Server URL, WS URL, dev password, notification channel ID |
| `lib/utils/app_colors.dart` | Dark theme constants |

## Key flows

- **Auth**: SplashScreen → `isLoggedIn()` → `/dashboard` or `/home` → LoginScreen → QRScannerScreen → DashboardScreen
- **WebSocket**: `DeviceWS` singleton — auto-reconnects, pushes status updates, handles `logout` commands
- **Background service**: `FlutterBackgroundService` foreground service (Android) — started on app launch, togglable from Dev Panel Settings
- **Updates**: Dev Panel → fetches releases from `arman29-dev/N.I.X-App` (public GitHub API), downloads via `open_filex`
- **Logout**: clears local data, disconnects WS, stops background service, navigates to `/dashboard`

## Known issues

- Registration API is a stub (`// TODO: Implement registration API call`)
- `launchers.dart` utility file is unused
- "Login with Passkey" and "Forgot Password" buttons have empty `onPressed`
- `register_device.dart` hardcodes WiFi interface `wlan0` (Android only)
- No token refresh mechanism — 30-day JWT expiry
- Server URL hardcoded in all API files and `device_ws.dart` — needs extraction to config

## Platform support

Configured for Android, iOS, macOS, Windows, Linux. Currently only tested on Android.
