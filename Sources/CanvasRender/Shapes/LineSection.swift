import CoreGraphics
import Foundation
import simd
import SwiftUI


public struct LineSection: DrawableShape, PartOfPath {
    let from: simd_double2
    let to: simd_double2

    public init(from: simd_double3, to: simd_double3, plane: AxisPlane) {
        self.from = plane.convert(from)
        self.to = plane.convert(to)
    }

    public init(from: simd_double2, to: simd_double2) {
        self.from = from
        self.to = to
    }

    public func drawPartOfPath(in context: CGContext, using transform: CGAffineTransform) {
        let a = CGPoint(x: from.x, y: from.y).applying(transform)
        let b = CGPoint(x: to.x, y: to.y).applying(transform)
        context.move(to: a)
        context.addLine(to: b)
    }

    public func draw(in context: CGContext, using transform: CGAffineTransform) {
        context.beginPath()
        drawPartOfPath(in: context, using: transform)
        context.strokePath()
    }
}
