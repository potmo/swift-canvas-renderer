import Foundation

public struct Pattern: DrawableShape {
    let spacing: Vector
    let count: Int
    let shapes: [DrawableShape]
    public init(_ spacing: Vector, count: Int, @CanvasBuilder _ builder: () -> [DrawableShape]) {
        self.spacing = spacing
        self.count = count
        self.shapes = builder()
    }

    public func draw(in context: RenderContext) {
        for i in 0 ..< count {
            let offsettingRenderTransformer = Offset.OffsetRenderTransformer(original: context.transform3d, offset: spacing.scaled(by: Double(i)))
            let newContext = RenderContext(canvasSize: context.canvasSize,
                                           renderTarget: context.renderTarget,
                                           color: context.color,
                                           lineWidth: context.lineWidth,
                                           lineStyle: context.lineStyle,
                                           transform2d: context.transform2d,
                                           transform3d: offsettingRenderTransformer)

            for shape in shapes {
                shape.draw(in: newContext)
            }
        }
    }
}
