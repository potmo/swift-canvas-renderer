import Foundation
import SwiftUI

struct RealtimeCanvasRenderer: NSViewRepresentable {
    typealias NSViewType = Canvas

    private let maker: any RealtimeShapeMaker

    private let renderTransform: RenderTransformer
    private let canvasSize: Vector2D
    private let view: RealtimeCanvas

    init(maker: any RealtimeShapeMaker,
         renderTransform: RenderTransformer,
         canvasSize: Vector2D) {
        self.maker = maker
        self.renderTransform = renderTransform
        self.canvasSize = canvasSize

        let view = RealtimeCanvas(maker: maker,
                                  renderTransform: renderTransform,
                                  canvasSize: canvasSize)

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            view.setNeedsDisplay(view.bounds)
        }

        self.view = view
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator()
        return coordinator
    }

    func makeNSView(context: Context) -> RealtimeCanvas {
        return view
    }

    func updateNSView(_ canvasView: RealtimeCanvas, context: Context) {
        canvasView.setNeedsDisplay(canvasView.bounds)
    }

    class Coordinator {
    }
}
