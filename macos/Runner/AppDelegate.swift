import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)

    for window in NSApp.windows {
      window.makeKeyAndOrderFront(nil)
      window.orderFrontRegardless()
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
