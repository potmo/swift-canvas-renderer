@testable import CanvasRender
import CoreGraphics
import Foundation
import simd
import Testing

struct ProjectedArcTests {
    func context(_ transform: RenderTransformer, flipY: Bool = false) -> RenderContext {
        RenderContext(canvasSize: Vector2D(1000, 800),
                      renderTarget: DXFRenderTarget(),
                      transform2d: flipY ? CGAffineTransform(scaleX: 2, y: -2) : .identity,
                      transform3d: transform)
    }

    /// The canvas end point of the arc must be where the rotated point projects to.
    func expectEndsAtRotatedPoint(pivot: Vector, point: Vector, angle: Double, axis: Vector, in context: RenderContext,
                                  sourceLocation: SourceLocation = #_sourceLocation) {
        guard case let .circular(center, radius, startAngle, sweep) = ProjectedArc(pivot: pivot, point: point, angle: angle, axis: axis, in: context) else {
            Issue.record("not circular", sourceLocation: sourceLocation)
            return
        }
        let start = CGPoint(x: center.x + radius * cos(startAngle), y: center.y + radius * sin(startAngle))
        let end = CGPoint(x: center.x + radius * cos(startAngle + sweep), y: center.y + radius * sin(startAngle + sweep))
        let expectedStart = context.transform(point)
        let expectedEnd = context.transform(pivot + Quat(angle: angle, axis: axis.normalized).act(point - pivot))
        #expect(hypot(start.x - expectedStart.x, start.y - expectedStart.y) < 1e-9, sourceLocation: sourceLocation)
        #expect(hypot(end.x - expectedEnd.x, end.y - expectedEnd.y) < 1e-9, sourceLocation: sourceLocation)
        // the midpoint too, which tells the two ways around the circle apart
        let mid = CGPoint(x: center.x + radius * cos(startAngle + sweep / 2), y: center.y + radius * sin(startAngle + sweep / 2))
        let expectedMid = context.transform(pivot + Quat(angle: angle / 2, axis: axis.normalized).act(point - pivot))
        #expect(hypot(mid.x - expectedMid.x, mid.y - expectedMid.y) < 1e-9, sourceLocation: sourceLocation)
    }

    @Test(arguments: [Vector(0, 0, 1), Vector(0, 0, -1)], [Double.pi / 2, -.pi / 3, 1.5 * .pi])
    func topViewArcsAreCircular(axis: Vector, angle: Double) {
        for flip in [false, true] {
            expectEndsAtRotatedPoint(pivot: [1, 2, 3], point: [4, 2, 3], angle: angle, axis: axis,
                                     in: context(OrthographicTransform(camera: .top()), flipY: flip))
        }
    }

    @Test func frontViewArcsAroundY() {
        expectEndsAtRotatedPoint(pivot: [1, 2, 3], point: [1, 2, 7], angle: 0.8, axis: [0, 1, 0],
                                 in: context(OrthographicTransform(camera: .front())))
        expectEndsAtRotatedPoint(pivot: [1, 2, 3], point: [1, 2, 7], angle: 0.8, axis: [0, -1, 0],
                                 in: context(AxisAlignedOrthographicTransform(plane: .xz)))
    }

    @Test func obliqueAndPerspectiveArcsAreNotCircular() {
        let oblique = Camera(eye: [100, -100, 100], target: .zero)
        if case .circular = ProjectedArc(pivot: .zero, point: [5, 0, 0], angle: 1, axis: [0, 0, 1], in: context(OrthographicTransform(camera: oblique))) {
            Issue.record("oblique view of a horizontal arc is an ellipse")
        }
        if case .circular = ProjectedArc(pivot: .zero, point: [5, 0, 0], angle: 1, axis: [0, 0, 1], in: context(PerspectiveTransform(camera: oblique))) {
            Issue.record("a tilted perspective view of an arc is not a circle")
        }
        // in a plane parallel to the image, perspective keeps circles round
        expectEndsAtRotatedPoint(pivot: .zero, point: [5, 0, 0], angle: 1, axis: [0, 0, 1],
                                 in: context(PerspectiveTransform(camera: .top())))
        // looking along the axis of a camera that is not axis aligned is still circular
        let axis = Vector(1, -1, 1).normalized
        expectEndsAtRotatedPoint(pivot: .zero, point: axis.arbitraryOrthogonal * 5, angle: 2, axis: axis,
                                 in: context(OrthographicTransform(camera: Camera(eye: axis * 100, target: .zero))))
    }
}
