import CoreGraphics
import Foundation
import simd
import SwiftUI


public struct Point: DrawableShape {
    let point: simd_double2

    public init(_ point: simd_double3, plane: AxisPlane) {
        self.point = plane.convert(point)
    }

    public init(_ point: simd_double2) {
        self.point = point
    }

    public func draw(in context: CGContext, using transform: CGAffineTransform) {
        let pos = point.cgPoint.applying(transform)

        context.beginPath()
        context.addArc(center: pos,
                       radius: 2,
                       startAngle: 0,
                       endAngle: .pi * 2,
                       clockwise: true)
        context.strokePath()
    }
}
