import Foundation
import simd
import SwiftUI

public struct CanvasView<StateType: ObservableObject>: View {
    private let maker: any ShapeMaker<StateType>
    @ObservedObject private var state: StateType
    private let renderTransform: RenderTransformer
    private let navigator: CanvasNavigator?

    public init(state: StateType, maker: any ShapeMaker<StateType>, renderTransform: RenderTransformer, navigator: CanvasNavigator? = nil) {
        self.maker = maker
        self._state = ObservedObject(wrappedValue: state)
        self.renderTransform = renderTransform
        self.navigator = navigator
    }

    public var body: some View {
        GeometryReader { proxy in
            CanvasRenderer(state: state,
                           maker: maker,
                           renderTransform: renderTransform,
                           canvasSize: Vector2D(x: proxy.size.width, y: proxy.size.height),
                           navigator: navigator)
        }
    }
}

public protocol ShapeMaker<StateType> {
    associatedtype StateType: ObservableObject
    @CanvasBuilder
    func shapes(from state: StateType) -> [any DrawableShape]
}
