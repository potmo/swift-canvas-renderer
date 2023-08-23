import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct Orbit: DrawableShape, PartOfPath {
    let pivot: simd_double3
    let point: simd_double3
    let rotation: simd_quatd
    let spokes: Bool

    public init(pivot: simd_double3, point: simd_double3, rotation: simd_quatd, spokes: Bool = false) {
        self.pivot = pivot
        self.point = point
        self.rotation = rotation
        self.spokes = spokes
    }

    public init(center: simd_double3, radius: Double, startAngle: Double, endAngle: Double, planeNormal: Vector, spokes: Bool = false) {
        self.pivot = center
        let lever = planeNormal.arbitraryOrthogonal
        self.point = Quat(angle: startAngle, axis: planeNormal).act(lever)
        self.rotation = Quat(angle: endAngle - startAngle, axis: planeNormal)
        self.spokes = spokes
    }

    public func draw(in context: RenderContext) {
        context.renderTarget.beginPath()
        drawPartOfPath(in: context)
        context.renderTarget.strokePath()

        if spokes {
            context.renderTarget.setStrokeColor(NSColor(context.color.opacity(0.1)).cgColor)
            let lever = point - pivot
            for t in stride(from: 0.0, through: 1.0, by: 0.1) {
                let rot = simd_slerp(.identity, rotation, t)
                let drawPoint = (pivot + rot.act(lever))
                context.renderTarget.beginPath()
                context.renderTarget.move(to: context.transform(pivot))
                context.renderTarget.addLine(to: context.transform(drawPoint))
                context.renderTarget.strokePath()
            }
            context.renderTarget.setStrokeColor(NSColor(context.color).cgColor)
            
            Circle(center: pivot, radius: 1).draw(in: context)
            
            Circle(center: point, radius: 1).draw(in: context)
        }
    }

    public func drawPartOfPath(in context: RenderContext) {
        let lever = point - pivot

        context.renderTarget.move(to: context.transform(point))

        for t in stride(from: 0.0, through: 1.0, by: 0.01) {
            let rot = simd_slerp(.identity, rotation, t)
            let drawPoint = (pivot + rot.act(lever))
            context.renderTarget.addLine(to: context.transform(drawPoint))
        }
    }
}
