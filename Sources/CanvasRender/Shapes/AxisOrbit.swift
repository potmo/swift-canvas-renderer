import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct AxisOrbit: DrawableShape, PartOfPath {
    let pivot: simd_double3
    let point: simd_double3
    let angle: Double
    let radius: Double
    let axis: simd_double3

    public init(pivot: simd_double3, point: simd_double3, angle: Double, axis: Vector) {
        self.pivot = pivot
        self.point = point
        self.angle = angle
        self.radius = (point - pivot).length
        self.axis = axis
    }

    public func draw(in context: RenderContext) {
        context.renderTarget.beginPath()
        drawPartOfPath(in: context)
        context.renderTarget.strokePath()
    }

    public func drawPartOfPath(in context: RenderContext) {
        let lever = (point - pivot).normalized.scaled(by: radius)
        context.renderTarget.addLine(to: context.transform(point))

        for t in stride(from: 0.0, through: 1.0, by: 0.01) {
            let rot = simd_quatd(angle: angle * t, axis: axis)
            let drawPoint = pivot + rot.act(lever)
            context.renderTarget.addLine(to: context.transform(drawPoint))
        }
    }
}
