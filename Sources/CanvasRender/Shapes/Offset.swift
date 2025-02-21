import Foundation

public struct Offset: DrawableShape, PartOfPath {
    let offset: Vector
    let shapeBuilder: () -> [DrawableShape]
    let partOfPathsBuilder: () -> [PartOfPath]

    public init(_ offset: Vector, @CanvasBuilder _ builder: @escaping () -> [DrawableShape]) {
        self.offset = offset
        self.shapeBuilder = builder
        self.partOfPathsBuilder = { [] }
    }

    public init(_ offset: Vector, @PathBuilder _ builder: @escaping () -> [PartOfPath]) {
        self.offset = offset
        self.shapeBuilder = { [] }
        self.partOfPathsBuilder = builder
    }

    public func drawPartOfPath(in context: RenderContext) {
        let offsettingRenderTransformer = OffsetRenderTransformer(original: context.transform3d, offset: offset)

        let newContext = RenderContext(canvasSize: context.canvasSize,
                                       renderTarget: context.renderTarget,
                                       color: context.color,
                                       lineWidth: context.lineWidth,
                                       lineStyle: context.lineStyle,
                                       transform2d: context.transform2d,
                                       transform3d: offsettingRenderTransformer)

        let partOfPaths = partOfPathsBuilder()
        for partOfPath in partOfPaths {
            partOfPath.drawPartOfPath(in: newContext)
        }
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

        let shapes = shapeBuilder()
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
            // FIXME: This needs to be fixedscaledFar
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
