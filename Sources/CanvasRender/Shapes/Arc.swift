import CoreGraphics
import Foundation
import simd
import SwiftUI


public struct Arc: DrawableShape, PartOfPath {
    let center: simd_double2
    let radius: simd_double1
    let startAngle: simd_double1
    let endAngle: simd_double1
    let clockwise: Bool

    public init(center: simd_double2, radius: simd_double1, startAngle: simd_double1, endAngle: simd_double1, clockwise: Bool = true) {
        self.center = center
        self.radius = radius
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.clockwise = true
    }

    public init(center: simd_double3, radius: simd_double1, startAngle: simd_double1, endAngle: simd_double1, clockwise: Bool = true, plane: AxisPlane) {
        self.center = center.inPlane(plane)
        self.radius = radius
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.clockwise = true
    }

    public func draw(in context: CGContext, using transform: CGAffineTransform) {
        context.beginPath()

        drawPartOfPath(in: context, using: transform)
        context.strokePath()
    }

    public func drawPartOfPath(in context: CGContext, using transform: CGAffineTransform) {
        let center = CGPoint(x: center.x, y: center.y).applying(transform)
        // compute the x-scaling bit of the transform
        let transformedRadius = radius * sqrt(Double(transform.a * transform.a + transform.c * transform.c))

        context.addArc(center: center,
                       radius: transformedRadius,
                       startAngle: startAngle,
                       endAngle: endAngle,
                       clockwise: !clockwise)
    }
}
