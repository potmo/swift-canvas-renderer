import Combine
import Foundation
import simd
import SwiftUI

struct CanvasRenderer<StateType: ObservableObject>: NSViewRepresentable {
    typealias NSViewType = Canvas

    private let maker: any ShapeMaker<StateType>
    @ObservedObject private var state: StateType
    private let renderTransform: RenderTransformer
    private let canvasSize: Vector2D
    private let view: Canvas<StateType>
    private var cancellable: AnyCancellable?

    init(state: StateType,
         maker: any ShapeMaker<StateType>,
         renderTransform: RenderTransformer,
         canvasSize: Vector2D) {
        self.maker = maker
        self.state = state
        self.renderTransform = renderTransform
        self.canvasSize = canvasSize

        let view = Canvas(state: state,
                          maker: maker,
                          renderTransform: renderTransform,
                          canvasSize: canvasSize)

        self.cancellable = state.objectWillChange.sink { _ in
            view.setNeedsDisplay(view.bounds)
        }

        self.view = view
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator()
        return coordinator
    }

    func makeNSView(context: Context) -> Canvas<StateType> {
        return view
    }

    func updateNSView(_ canvasView: Canvas<StateType>, context: Context) {
        canvasView.setNeedsDisplay(canvasView.bounds)
    }

    class Coordinator {
    }
}

