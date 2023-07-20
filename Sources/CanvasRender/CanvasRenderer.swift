import Foundation
import simd
import SwiftUI

struct CanvasRenderer<StateType: ObservableObject>: NSViewRepresentable {
    typealias NSViewType = Canvas

    private let maker: any ShapeMaker<StateType>
    @ObservedObject private var state: StateType

    init(state: StateType,
         maker: any ShapeMaker<StateType>) {
        self.maker = maker
        self.state = state
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator()

        return coordinator
    }

    func makeNSView(context: Context) -> Canvas<StateType> {
        let view = Canvas(state: state,
                          maker: maker)

        return view
    }

    func updateNSView(_ canvasView: Canvas<StateType>, context: Context) {
        canvasView.setNeedsDisplay(canvasView.bounds)
    }

    class Coordinator {
    }
}
