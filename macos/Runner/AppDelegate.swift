import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Single-instance enforcement: bring the existing window to front if
    // another MIDIFlow is already running, then exit this duplicate.
    let runningApps = NSWorkspace.shared.runningApplications
    let currentApp = NSRunningApplication.current
    for app in runningApps {
      if app.bundleIdentifier == currentApp.bundleIdentifier && app != currentApp {
        app.activate(options: NSApplication.ActivationOptions(rawValue: 0))
        NSApp.terminate(nil)
        return
      }
    }
  }
}
