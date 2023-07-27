import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct Orbit: DrawableShape, PartOfPath {
    let pivot: simd_double3
    let point: simd_double3
    let rotation: simd_quatd

    public init(pivot: simd_double3, point: simd_double3, rotation: simd_quatd) {
        self.pivot = pivot
        self.point = point
        self.rotation = rotation
    }

    public init(center: simd_double3, radius: Double, startAngle: Double, endAngle: Double, planeNormal: Vector) {
        self.pivot = center
        self.point = Quat(angle: startAngle, axis: planeNormal).act(Vector(radius, 0, 0))
        self.rotation = Quat(angle: endAngle - startAngle, axis: planeNormal)
    }

    public func draw(in context: RenderContext) {
        context.cgContext.beginPath()
        drawPartOfPath(in: context)
        context.cgContext.strokePath()
    }

    public func drawPartOfPath(in context: RenderContext) {
        let lever = point - pivot

        context.cgContext.move(to: context.transform(point))

        for t in stride(from: 0.0, through: 1.0, by: 0.01) {
            let rot = simd_slerp(.identity, rotation, t)
            let drawPoint = (pivot + rot.act(lever))
            context.cgContext.addLine(to: context.transform(drawPoint))
        }
    }
}
