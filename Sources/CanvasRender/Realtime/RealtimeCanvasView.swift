import Foundation
import SwiftUI

public struct RealtimeCanvasView: View {
    private let maker: any RealtimeShapeMaker
    private let renderTransform: RenderTransformer

    public init(maker: any RealtimeShapeMaker, renderTransform: RenderTransformer) {
        self.maker = maker
        self.renderTransform = renderTransform
    }

    public var body: some View {
        GeometryReader { proxy in
            RealtimeCanvasRenderer(maker: maker,
                                   renderTransform: renderTransform,
                                   canvasSize: Vector2D(x: proxy.size.width, y: proxy.size.height))
        }
    }
}

public protocol RealtimeShapeMaker {
    @CanvasBuilder
    func shapes() -> [any DrawableShape]
}
