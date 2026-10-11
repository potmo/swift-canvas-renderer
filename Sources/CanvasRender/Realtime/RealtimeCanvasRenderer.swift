import Foundation
import SwiftUI

struct RealtimeCanvasRenderer: NSViewRepresentable {
    private let maker: any RealtimeShapeMaker
    private let renderTransform: RenderTransformer
    private let canvasSize: Vector2D

    init(maker: any RealtimeShapeMaker,
         renderTransform: RenderTransformer,
         canvasSize: Vector2D) {
        self.maker = maker
        self.renderTransform = renderTransform
        self.canvasSize = canvasSize
    }

    // SwiftUI recreates this struct on every update, so the view is only created here, once.
    // It redraws itself every display refresh (see RealtimeCanvas.viewDidMoveToWindow).
    func makeNSView(context: Context) -> RealtimeCanvas {
        RealtimeCanvas(maker: maker,
                       renderTransform: renderTransform,
                       canvasSize: canvasSize)
    }

    func updateNSView(_ canvasView: RealtimeCanvas, context: Context) {
        canvasView.needsDisplay = true
    }
}
