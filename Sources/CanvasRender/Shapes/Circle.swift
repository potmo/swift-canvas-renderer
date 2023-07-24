import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct Circle: DrawableShape {
    let center: simd_double2
    let radius: simd_double1

    public init(center: simd_double2, radius: simd_double1) {
        self.center = center
        self.radius = radius
    }

    public init(center: simd_double3, radius: simd_double1, plane: AxisPlane) {
        self.center = center.inPlane(plane)
        self.radius = radius
    }

    public func draw(in context: CGContext, using transform: CGAffineTransform) {
        let center = CGPoint(x: center.x, y: center.y).applying(transform)

        // compute the x-scaling bit of the transform
        let transformedRadius = radius * sqrt(Double(transform.a * transform.a + transform.c * transform.c))

        context.beginPath()
        context.addArc(center: center,
                       radius: transformedRadius,
                       startAngle: 0,
                       endAngle: .pi * 2,
                       clockwise: true)
        context.closePath()
        context.strokePath()
    }
}
