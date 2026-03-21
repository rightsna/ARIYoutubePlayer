import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var normalFrame: NSRect?

  override func awakeFromNib() {
    NSLog("[youtubeplayer] CommandLine.arguments = %@", CommandLine.arguments.joined(separator: " | "))
    let project = FlutterDartProject()
    project.dartEntrypointArguments = Array(CommandLine.arguments.dropFirst())
    NSLog(
      "[youtubeplayer] dartEntrypointArguments = %@",
      project.dartEntrypointArguments?.joined(separator: " | ") ?? "<nil>"
    )
    let flutterViewController = FlutterViewController(project: project)
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    configureWindowChannel(flutterViewController)

    super.awakeFromNib()
  }

  private func configureWindowChannel(_ flutterViewController: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "youtubeplayer/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "startDragging" {
        if let event = NSApp.currentEvent {
          self?.performDrag(with: event)
        }
        result(nil)
        return
      }

      guard call.method == "setMiniMode" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard
        let args = call.arguments as? [String: Any],
        let enabled = args["enabled"] as? Bool
      else {
        result(
          FlutterError(
            code: "invalid_args",
            message: "Missing enabled flag",
            details: nil
          )
        )
        return
      }

      self?.applyMiniMode(enabled)
      result(nil)
    }
  }

  private func applyMiniMode(_ enabled: Bool) {
    if enabled {
      if normalFrame == nil {
        normalFrame = frame
      }

      let miniSize = NSSize(width: 420, height: 110)
      let topLeft = NSPoint(x: frame.minX, y: frame.maxY)
      let miniOrigin = NSPoint(x: topLeft.x, y: topLeft.y - miniSize.height)
      let miniFrame = NSRect(origin: miniOrigin, size: miniSize)

      setFrame(miniFrame, display: true, animate: true)
      standardWindowButton(.closeButton)?.isHidden = true
      standardWindowButton(.miniaturizeButton)?.isHidden = true
      standardWindowButton(.zoomButton)?.isHidden = true
      styleMask.remove(.resizable)
      styleMask.insert(.fullSizeContentView) // 타이틀바 영역까지 콘텐츠를 확장하여 투명하게 렌더링되게 합니다.
      isMovableByWindowBackground = true
      titleVisibility = .hidden
      titlebarAppearsTransparent = true
    } else {
      if let frame = normalFrame {
        setFrame(frame, display: true, animate: true)
      }

      standardWindowButton(.closeButton)?.isHidden = false
      standardWindowButton(.miniaturizeButton)?.isHidden = false
      standardWindowButton(.zoomButton)?.isHidden = false
      styleMask.insert(.resizable)
      styleMask.remove(.fullSizeContentView) // 원래대로 복구
      titleVisibility = .visible
      titlebarAppearsTransparent = false
      normalFrame = nil
    }

    makeKeyAndOrderFront(nil)
    orderFrontRegardless()
  }
}
