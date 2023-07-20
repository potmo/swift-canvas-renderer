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

    var body: some Scene {
        WindowGroup("Shape drawing") {
            CanvasView {
                Decoration(color: .blue) {
                    Circle(center: [0, 0], radius: 10.0)
                }
                Circle(center: [20, 0], radius: 10.0)
                LineSection(from: [0, 0], to: [20, 0])
                Point(at: [30, 10])
                Decoration(color: .green, lineStyle: .dashed(phase: 2, lengths: [3, 3])) {
                    Arc(center: [40, 0], radius: 10.0, startAngle: 0, endAngle: .pi * 1.5)
                }

                Decoration(lineWidth: 2.0) {
                    Path {
                        MoveTo(point: [0, 50])
                        LineTo(point: [100, 50])
                        Arc(center: [100, 60], radius: 10, startAngle: 0, endAngle: .pi)
                    }
                }
            }

            .background(Color(red: 240 / 255, green: 245 / 255, blue: 250 / 255))
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
