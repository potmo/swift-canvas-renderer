import CoreGraphics
import Foundation
import simd

/// How the arc traced by rotating `point` around the line through `pivot` along `axis` appears on the canvas.
enum ProjectedArc {
    /// A circular arc on the canvas: from `startAngle`, sweeping `sweep` radians (counterclockwise when positive).
    case circular(center: CGPoint, radius: CGFloat, startAngle: CGFloat, sweep: CGFloat)
    /// A point: the rotated point is on the axis.
    case point(CGPoint)
    /// Not a circle on the canvas: an ellipse or a line (the arc's plane isn't parallel to the canvas), or
    /// a projection that isn't affine (perspective).
    case other

    init(pivot: Vector, point: Vector, angle: Double, axis: Vector, in context: RenderContext) {
        let axis = axis.normalized
        let lever = point - pivot
        // the circle's center and radius vector, also when `point` isn't in the plane through `pivot`
        let center = pivot + axis * lever.dot(axis)
        let u = lever - axis * lever.dot(axis)
        // u rotated 90 degrees around the axis (right-hand rule)
        let v = axis.cross(u)

        let projectedCenter = context.transform(center)
        guard u.length > 1e-12, !axis.isNaN else {
            self = .point(projectedCenter)
            return
        }

        let projectedU = context.transform(center + u) - projectedCenter
        let projectedV = context.transform(center + v) - projectedCenter
        let lengthU = projectedU.length
        let lengthV = projectedV.length
        let tolerance = 1e-9 * max(1, lengthU, lengthV)

        // round: both radius vectors equally long and perpendicular on the canvas
        guard lengthU > tolerance, abs(lengthU - lengthV) <= tolerance, abs(projectedU.dot(projectedV)) <= tolerance * max(lengthU, 1) else {
            self = .other
            return
        }

        // affine: points in between end up where an affine projection would put them
        for t in [0.7, 2.3, 4.1] {
            let expected = projectedCenter + projectedU * cos(t) + projectedV * sin(t)
            let actual = context.transform(center + u * cos(t) + v * sin(t))
            guard hypot(actual.x - expected.x, actual.y - expected.y) <= tolerance else {
                self = .other
                return
            }
        }

        // a mirroring projection turns the rotation around
        let orientation: Double = projectedU.x * projectedV.y - projectedU.y * projectedV.x > 0 ? 1 : -1
        self = .circular(center: projectedCenter,
                         radius: lengthU,
                         startAngle: atan2(projectedU.y, projectedU.x),
                         sweep: angle * orientation)
    }
}

private extension CGPoint {
    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func * (lhs: CGPoint, rhs: Double) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    var length: Double {
        hypot(x, y)
    }

    func dot(_ other: CGPoint) -> Double {
        x * other.x + y * other.y
    }
}
