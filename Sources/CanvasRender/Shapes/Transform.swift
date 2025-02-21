import Foundation

public struct Flip: DrawableShape {
    let flipPoint: Vector
    let flipDirection: Vector
    let angle: Double
    let shapes: [DrawableShape]
    public init(at flipPoint: Vector, around flipDirection: Vector, by angle: Double, @CanvasBuilder _ builder: () -> [DrawableShape]) {
        self.flipPoint = flipPoint
        self.flipDirection = flipDirection
        self.angle = angle
        self.shapes = builder()
    }

    //
    // FIXME: Flip in conjunction with drawing arcs messes the arcs up since the axis is not properly flipped
    //

    public func draw(in context: RenderContext) {
        let flippingRenderTransformer = FlipRenderTransformer(original: context.transform3d,
                                                              flipPoint: flipPoint,
                                                              flipDirection: flipDirection,
                                                              angle: angle)

        let newContext = RenderContext(canvasSize: context.canvasSize,
                                       renderTarget: context.renderTarget,
                                       color: context.color,
                                       lineWidth: context.lineWidth,
                                       lineStyle: context.lineStyle,
                                       transform2d: context.transform2d,
                                       transform3d: flippingRenderTransformer)

        for shape in shapes {
            shape.draw(in: newContext)
        }
    }

    struct FlipRenderTransformer: RenderTransformer {
        let original: RenderTransformer
        let flipPoint: Vector
        let flipDirection: Vector
        let angle: Double

        init(original: RenderTransformer, flipPoint: Vector, flipDirection: Vector, angle: Double) {
            self.original = original
            self.flipPoint = flipPoint
            self.flipDirection = flipDirection
            self.angle = angle
        }

        func apply(point: Vector, canvasSize: Vector2D) -> Vector2D {
            let flippedPoint = self.rotateAroundLine(position: point, linePoint: flipPoint, lineDirection: flipDirection, angle: angle)
            return original.apply(point: flippedPoint, canvasSize: canvasSize)
        }

        private func rotateAroundLine(position: Vector, linePoint: Vector, lineDirection: Vector, angle: Double) -> SIMD3<Double> {
            // Normalize the direction vector
            let normalizedDirection = lineDirection.normalized

            // Translate the position so the line point is at the origin
            let translatedPosition = position - linePoint

            // Components of Rodrigues' rotation formula
            let cosAngle = cos(angle)
            let sinAngle = sin(angle)
            let dotProduct = normalizedDirection.dot(translatedPosition)
            let crossProduct = normalizedDirection.cross(translatedPosition)

            // Rodrigues' rotation formula
            let rotatedPosition = translatedPosition * cosAngle +
                crossProduct * sinAngle +
                normalizedDirection * dotProduct * (1 - cosAngle)

            // Translate back to the original position
            return rotatedPosition + linePoint
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
