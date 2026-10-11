import Foundation
import simd
import SwiftUI

struct CanvasRenderer<StateType: ObservableObject>: NSViewRepresentable {
    private let maker: any ShapeMaker<StateType>
    // Observed so SwiftUI calls updateNSView (and the canvas redraws) whenever the state changes.
    @ObservedObject private var state: StateType
    private let renderTransform: RenderTransformer
    private let canvasSize: Vector2D
    private let navigator: CanvasNavigator?

    init(state: StateType,
         maker: any ShapeMaker<StateType>,
         renderTransform: RenderTransformer,
         canvasSize: Vector2D,
         navigator: CanvasNavigator? = nil) {
        self.maker = maker
        self.navigator = navigator
        self._state = ObservedObject(wrappedValue: state)
        self.renderTransform = renderTransform
        self.canvasSize = canvasSize
    }

    // SwiftUI recreates this struct on every update, so the view is only created here, once.
    func makeNSView(context: Context) -> Canvas<StateType> {
        let view = Canvas(state: state,
                          maker: maker,
                          renderTransform: renderTransform,
                          canvasSize: canvasSize)
        navigator?.canvas = view
        return view
    }

    func updateNSView(_ canvasView: Canvas<StateType>, context: Context) {
        canvasView.maker = maker
        canvasView.state = state
        canvasView.renderTransform = renderTransform
        navigator?.canvas = canvasView
        canvasView.needsDisplay = true
    }
}
