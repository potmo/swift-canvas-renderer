import CoreGraphics
import Foundation
import simd
import SwiftUI


public struct Orbit: DrawableShape, PartOfPath {
    let pivot: simd_double3
    let point: simd_double3
    let rotation: simd_quatd
    let renderPlane: AxisPlane

    public init(pivot: simd_double3, point: simd_double3, rotation: simd_quatd, renderPlane: AxisPlane) {
        self.pivot = pivot
        self.point = point
        self.rotation = rotation
        self.renderPlane = renderPlane
    }

    public func draw(in context: CGContext, using transform: CGAffineTransform) {
        context.beginPath()
        drawPartOfPath(in: context, using: transform)
        context.strokePath()
    }

    public func drawPartOfPath(in context: CGContext, using transform: CGAffineTransform) {
        let lever = point - pivot

        context.move(to: point.inPlane(renderPlane).cgPoint.applying(transform))

        for t in stride(from: 0.0, through: 1.0, by: 0.01) {
            let rot = simd_slerp(.identity, rotation, t)
            let drawPoint = (pivot + rot.act(lever)).inPlane(renderPlane).cgPoint.applying(transform)
            context.addLine(to: drawPoint)
        }
    }
}
