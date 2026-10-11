import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct Arc: DrawableShape, PartOfPath {
    let pivot: simd_double3
    let point: simd_double3
    let angle: Double
    let radius: Double
    let axis: simd_double3
    let arcResolutuon: Double

    public init(pivot: simd_double3, point: simd_double3, angle: Double, axis: Vector, arcResolutuon: Double = 0.3) {
        self.pivot = pivot
        self.point = point
        self.angle = angle
        self.radius = (point - pivot).length
        self.axis = axis
        self.arcResolutuon = arcResolutuon
    }

    public func draw(in context: RenderContext) {
        context.renderTarget.beginPath(id: nil)
        drawPartOfPath(in: context)
        context.renderTarget.strokePath()
    }

    public func drawPartOfPath(in context: RenderContext) {
        switch ProjectedArc(pivot: pivot, point: point, angle: angle, axis: axis, in: context) {
        case let .circular(center, radius, startAngle, sweep):
            // make sure the we draw a line to the start position first and end up at the end position
            context.renderTarget.move(to: context.transform(point))
            if abs(angle) >= .pi * 2 - 1e-12 {
                context.renderTarget.circle(center: center, radius: radius)
            } else {
                context.renderTarget.arc(center: center,
                                         radius: radius,
                                         startAngle: startAngle,
                                         endAngle: startAngle + sweep,
                                         counterClockwise: sweep > 0)
            }
            context.renderTarget.move(to: context.transform(pivot + Quat(angle: angle, axis: axis).act(point - pivot)))
        case .point, .other:
            drawWithPoints(in: context)
        }
    }

    private func drawWithPoints(in context: RenderContext) {
        let lever = (point - pivot).normalized.scaled(by: radius)
        context.renderTarget.move(to: context.transform(point))

        let arcLength = abs(angle) * radius

        for t in stride(from: 0.0, through: arcLength, by: arcResolutuon) {
            let interpolatedAngle: Double

            if arcLength == 0 {
                interpolatedAngle = 0
            } else {
                interpolatedAngle = angle * t / arcLength
            }

            let rot = simd_quatd(angle: interpolatedAngle, axis: axis)
            let drawPoint = pivot + rot.act(lever)
            context.renderTarget.addLine(to: context.transform(drawPoint))
        }

        let rot = simd_quatd(angle: angle, axis: axis)
        let drawPoint = pivot + rot.act(lever)
        context.renderTarget.addLine(to: context.transform(drawPoint))
    }
}
