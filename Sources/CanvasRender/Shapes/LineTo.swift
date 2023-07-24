import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct LineTo: PartOfPath {
    let point: simd_double2

    public init(_ point: simd_double2) {
        self.point = point
    }

    public init(_ point: simd_double3, plane: AxisPlane) {
        self.point = point.inPlane(plane)
    }

    public func drawPartOfPath(in context: CGContext, using transform: CGAffineTransform) {
        let a = CGPoint(x: point.x, y: point.y).applying(transform)
        context.addLine(to: a)
    }
}
