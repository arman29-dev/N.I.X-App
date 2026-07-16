import Cocoa
import FlutterMacOS
import UserNotifications

@main
class AppDelegate: FlutterAppDelegate {

  private var statusItem: NSStatusItem?
  private var isDockIconVisible = true

  override func applicationDidFinishLaunching(_ notification: Notification) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if let error = error {
        NSLog("[NIX] Notification auth error: \(error.localizedDescription)")
      } else {
        NSLog("[NIX] Notification permission granted: \(granted)")
      }
    }

    setupNotificationChannel()
    setupMenuBarIcon()

    if let window = NSApp.windows.first(where: { $0 is MainFlutterWindow }) {
      let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
      let width: CGFloat = 420
      let height: CGFloat = 870
      let x = screenFrame.minX + (screenFrame.width - width) / 2
      let y = screenFrame.minY + (screenFrame.height - height) / 2
      window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
      window.minSize = NSSize(width: 360, height: 700)
      window.aspectRatio = NSSize(width: 9, height: 19.5)
      window.title = "N.I.X"
      window.makeKeyAndOrderFront(nil)
    }
  }

  // MARK: - Menu Bar

  private func setupNotificationChannel() {
    guard let window = NSApp.windows.first(where: { $0 is MainFlutterWindow }),
          let controller = window.contentViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "nix/notifications",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "showMessageNotification":
        let senderName = (call.arguments as? [String: Any])?["sender_name"] as? String ?? "Device"
        let message = (call.arguments as? [String: Any])?["message"] as? String ?? ""
        self?.showMessageNotification(senderName: senderName, message: message)
        result(true)
      case "showFileNotification":
        let fileName = (call.arguments as? [String: Any])?["file_name"] as? String ?? "File"
        let fileSize = (call.arguments as? [String: Any])?["file_size"] as? String ?? "Unknown size"
        self?.showFileNotification(fileName: fileName, fileSize: fileSize)
        result(true)
      case "showUpdateNotification":
        let title = (call.arguments as? [String: Any])?["title"] as? String ?? "Update Available"
        let body = (call.arguments as? [String: Any])?["body"] as? String ?? "A new version is available"
        self?.showUpdateNotification(title: title, body: body)
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func showMessageNotification(senderName: String, message: String) {
    let content = UNMutableNotificationContent()
    content.title = "Message from \(senderName)"
    content.body = message.count > 80 ? "\(message.prefix(80))..." : message
    content.sound = .default

    let request = UNNotificationRequest(
      identifier: "nix-message-\(UUID().uuidString)",
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
  }

  private func showFileNotification(fileName: String, fileSize: String) {
    let content = UNMutableNotificationContent()
    content.title = "File received: \(fileName)"
    content.body = "\(fileSize) — Tap to view in chat"
    content.sound = .default

    let request = UNNotificationRequest(
      identifier: "nix-file-\(UUID().uuidString)",
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
  }

  private func showUpdateNotification(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    let request = UNNotificationRequest(
      identifier: "nix-update-\(UUID().uuidString)",
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
  }

  // MARK: - Menu Bar

  private func setupMenuBarIcon() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem?.button?.image = createMenuBarIcon()

    let menu = NSMenu()
    menu.addItem(NSMenuItem(title: "Show N.I.X", action: #selector(showWindow), keyEquivalent: ""))
    menu.addItem(NSMenuItem.separator())

    let dockItem = NSMenuItem(title: "Hide from Dock", action: #selector(toggleDockIcon), keyEquivalent: "")
    dockItem.image = createEyeIcon()
    dockItem.image?.isTemplate = true
    menu.addItem(dockItem)

    menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ","))

    let refreshItem = NSMenuItem(title: "Refresh Connection", action: #selector(refreshConnection), keyEquivalent: "r")
    refreshItem.image = createRefreshIcon()
    refreshItem.image?.isTemplate = true
    menu.addItem(refreshItem)

    menu.addItem(NSMenuItem.separator())
    menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
    statusItem?.menu = menu
  }

  private func createMenuBarIcon() -> NSImage {
    let size = NSSize(width: 20, height: 20)
    let image = NSImage(size: size, flipped: false) { _ in
      let outline = NSBezierPath()
      outline.move(to: NSPoint(x: 10, y: 1.67))
      outline.line(to: NSPoint(x: 18.33, y: 5.83))
      outline.line(to: NSPoint(x: 18.33, y: 14.17))
      outline.line(to: NSPoint(x: 10, y: 18.33))
      outline.line(to: NSPoint(x: 1.67, y: 14.17))
      outline.line(to: NSPoint(x: 1.67, y: 5.83))
      outline.close()

      let crossbar = NSBezierPath()
      crossbar.move(to: NSPoint(x: 1.67, y: 5.83))
      crossbar.line(to: NSPoint(x: 10, y: 10))
      crossbar.line(to: NSPoint(x: 18.33, y: 5.83))

      let vertical = NSBezierPath()
      vertical.move(to: NSPoint(x: 10, y: 18.33))
      vertical.line(to: NSPoint(x: 10, y: 10))

      NSColor.black.setStroke()
      for p in [outline, crossbar, vertical] {
        p.lineWidth = 1.5
        p.lineCapStyle = .round
        p.lineJoinStyle = .round
        p.stroke()
      }
      return true
    }
    image.isTemplate = true
    return image
  }

  private func createEyeIcon() -> NSImage {
    let size = NSSize(width: 16, height: 16)
    return NSImage(size: size, flipped: false) { _ in
      let eye = NSBezierPath()
      eye.move(to: NSPoint(x: 2, y: 8))
      eye.curve(to: NSPoint(x: 14, y: 8),
                controlPoint1: NSPoint(x: 5, y: 3),
                controlPoint2: NSPoint(x: 11, y: 3))
      eye.curve(to: NSPoint(x: 2, y: 8),
                controlPoint1: NSPoint(x: 11, y: 13),
                controlPoint2: NSPoint(x: 5, y: 13))
      NSColor.black.setStroke()
      eye.lineWidth = 1.5
      eye.lineCapStyle = .round
      eye.stroke()

      let pupil = NSBezierPath(ovalIn: NSRect(x: 6.5, y: 6.5, width: 3, height: 3))
      NSColor.black.setFill()
      pupil.fill()
      return true
    }
  }

  private func createEyeSlashIcon() -> NSImage {
    let size = NSSize(width: 16, height: 16)
    return NSImage(size: size, flipped: false) { _ in
      let eye = NSBezierPath()
      eye.move(to: NSPoint(x: 2, y: 8))
      eye.curve(to: NSPoint(x: 14, y: 8),
                controlPoint1: NSPoint(x: 5, y: 3),
                controlPoint2: NSPoint(x: 11, y: 3))
      eye.curve(to: NSPoint(x: 2, y: 8),
                controlPoint1: NSPoint(x: 11, y: 13),
                controlPoint2: NSPoint(x: 5, y: 13))
      NSColor.black.setStroke()
      eye.lineWidth = 1.5
      eye.lineCapStyle = .round
      eye.stroke()

      let slash = NSBezierPath()
      slash.move(to: NSPoint(x: 3, y: 3))
      slash.line(to: NSPoint(x: 13, y: 13))
      NSColor.black.setStroke()
      slash.lineWidth = 1.5
      slash.lineCapStyle = .round
      slash.stroke()
      return true
    }
  }

  private func createRefreshIcon() -> NSImage {
    if let existing = NSImage(named: NSImage.refreshTemplateName) {
      return existing
    }
    let size = NSSize(width: 16, height: 16)
    return NSImage(size: size, flipped: false) { _ in
      let center = NSPoint(x: 8, y: 8)
      let path = NSBezierPath()
      path.appendArc(withCenter: center, radius: 6,
                     startAngle: 270, endAngle: 180,
                     clockwise: true)
      NSColor.black.setStroke()
      path.lineWidth = 1.5
      path.lineCapStyle = .round
      path.stroke()

      let arrow = NSBezierPath()
      arrow.move(to: NSPoint(x: 2.5, y: 4))
      arrow.line(to: NSPoint(x: 2.5, y: 7))
      arrow.line(to: NSPoint(x: 5.5, y: 5.5))
      arrow.close()
      NSColor.black.setFill()
      arrow.fill()
      return true
    }
  }

  @objc private func showWindow() {
    for window in NSApp.windows {
      window.makeKeyAndOrderFront(nil)
    }
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc private func toggleDockIcon() {
    isDockIconVisible.toggle()
    if isDockIconVisible {
      NSApp.setActivationPolicy(.regular)
    } else {
      NSApp.setActivationPolicy(.accessory)
    }
    if let menu = statusItem?.menu,
       let item = menu.item(at: 2) {
      item.title = isDockIconVisible ? "Hide from Dock" : "Show in Dock"
      item.image = isDockIconVisible ? createEyeIcon() : createEyeSlashIcon()
      item.image?.isTemplate = true
    }
  }

  @objc private func openSettings() {
    showWindow()
    sendToFlutter(method: "openDevPanel")
  }

  @objc private func refreshConnection() {
    sendToFlutter(method: "refreshConnection")
  }

  private func sendToFlutter(method: String) {
    guard let window = NSApp.windows.first(where: { $0 is MainFlutterWindow }),
          let controller = window.contentViewController as? FlutterViewController else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "nix/menu",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.invokeMethod(method, arguments: nil)
  }

  @objc private func quitApp() {
    NSApp.terminate(nil)
  }

  // MARK: - App Lifecycle

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      for window in NSApp.windows {
        window.makeKeyAndOrderFront(nil)
      }
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
