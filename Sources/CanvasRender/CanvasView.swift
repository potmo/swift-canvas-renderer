import Foundation
import simd
import SwiftUI

public struct CanvasView<StateType: ObservableObject>: View {
    private let maker: any ShapeMaker<StateType>
    @ObservedObject private var state: StateType
    private let renderTransform: RenderTransformer

    public init(@ObservedObject state: StateType, maker: any ShapeMaker<StateType>, renderTransform: RenderTransformer) {
        self.maker = maker
        self.state = state
        self.renderTransform = renderTransform
    }

    public var body: some View {
        GeometryReader { proxy in
            CanvasRenderer(state: state,
                           maker: maker,
                           renderTransform: renderTransform,
                           canvasSize: Vector2D(x: proxy.size.width, y: proxy.size.height))
        }
    }
}

public protocol ShapeMaker<StateType> {
    associatedtype StateType: ObservableObject
    @CanvasBuilder
    func shapes(from state: StateType) -> [any DrawableShape]
}
