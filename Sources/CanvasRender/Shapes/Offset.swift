import Foundation

public struct Offset: DrawableShape {
    let offset: Vector
    let shapes: [DrawableShape]
    public init(_ offset: Vector, @CanvasBuilder _ builder: () -> [DrawableShape]) {
        self.offset = offset
        self.shapes = builder()
    }

    public func draw(in context: RenderContext) {
        let offsettingRenderTransformer = OffsetRenderTransformer(original: context.transform3d, offset: offset)

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

    struct OffsetRenderTransformer: RenderTransformer {
        let original: RenderTransformer
        let offset: Vector

        init(original: RenderTransformer, offset: Vector) {
            self.original = original
            self.offset = offset
        }

        func apply(point: Vector, canvasSize: Vector2D) -> Vector2D {
            return original.apply(point: point + offset, canvasSize: canvasSize)
        }

        func unapply(point: Vector2D, canvasSize: Vector2D) -> Ray {
            //FIXME: This needs to be fixedscaledFar
            return original.unapply(point: point, canvasSize: canvasSize)
        }

        var cameraDirection: Vector {
            return original.cameraDirection
        }

        var isTopDownOrthographic: Bool {
            return original.isTopDownOrthographic
        }
    }
}
