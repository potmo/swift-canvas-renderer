import simd
import SwiftUI
import CanvasRender

@main
struct Main: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    @StateObject private var state = DemoState()

    var body: some Scene {
        WindowGroup("Shape drawing") {
            CanvasView(state: state, maker: DemoShapes(), renderTransform: OrthographicTransform(camera: Camera.top()))
                .background(Color(red: 240 / 255, green: 245 / 255, blue: 250 / 255))
        }
    }
}

final class DemoState: ObservableObject {}

/// Drawn with a top view: X right, Y up.
struct DemoShapes: ShapeMaker {
    func shapes(from state: DemoState) -> [any DrawableShape] {
        Decoration(color: .blue) {
            Circle(center: [0, 0, 0], radius: 10.0)
        }
        Circle(center: [20, 0, 0], radius: 10.0)
        LineSection(from: [0, 0, 0], to: [20, 0, 0])
        Decoration(color: .green, lineStyle: .dashed(phase: 2, lengths: [3, 3])) {
            Arc(pivot: [40, 0, 0], point: [50, 0, 0], angle: .pi * 1.5, axis: [0, 0, 1])
        }
        Decoration(lineWidth: 2.0) {
            Path {
                MoveTo([0, 50, 0])
                LineTo([100, 50, 0])
                Arc(pivot: [100, 60, 0], point: [100, 50, 0], angle: .pi, axis: [0, 0, 1])
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
