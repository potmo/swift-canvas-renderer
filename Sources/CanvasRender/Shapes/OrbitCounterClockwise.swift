import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct OrbitCounterClockwise: DrawableShape, PartOfPath {
    let pivot: simd_double3
    let point: simd_double3
    let rotation: simd_quatd
    let spokes: Bool
    let arcResolutuon: Double

    public init(pivot: simd_double3, point: simd_double3, rotation: simd_quatd, spokes: Bool = false, arcResolutuon: Double = 0.3) {
        self.pivot = pivot
        self.point = point
        self.rotation = rotation
        self.spokes = spokes
        self.arcResolutuon = arcResolutuon
    }

    public init(center: simd_double3, radius: Double, startAngle: Double, endAngle: Double, planeNormal: Vector, spokes: Bool = false, arcResolutuon: Double = 0.3) {
        let lever = planeNormal.arbitraryOrthogonal
        let point = Quat(angle: startAngle, axis: planeNormal).act(lever)
        let rotation = Quat(angle: endAngle - startAngle, axis: planeNormal)

        self.init(pivot: center, point: point, rotation: rotation, spokes: spokes, arcResolutuon: arcResolutuon)
    }

    public func draw(in context: RenderContext) {
        context.renderTarget.beginPath()
        drawPartOfPath(in: context)
        context.renderTarget.strokePath()

        if spokes {
            context.renderTarget.setStrokeColor(context.color.opacity(0.1).cgColor)
            let lever = point - pivot
            for t in stride(from: 0.0, through: 1.0, by: 0.1) {
                let rot = simd_slerp(.identity, rotation, t)
                let drawPoint = (pivot + rot.act(lever))
                context.renderTarget.beginPath()
                context.renderTarget.move(to: context.transform(pivot))
                context.renderTarget.addLine(to: context.transform(drawPoint))
                context.renderTarget.strokePath()
            }
            context.renderTarget.setStrokeColor(context.color.cgColor)

            Circle(center: pivot, radius: 1).draw(in: context)

            Circle(center: point, radius: 1).draw(in: context)
        }
    }

    public func drawPartOfPath(in context: RenderContext) {
        let axisIsAlignedWithCameraAxis = context.transform(Vector(0, 0, 0)) == context.transform(Vector(0, 0, 1))
        let axisIsAlignedWithZ = abs(rotation.axis.dot(Vector(0, 0, 1))) >= 1.0 - .ulpOfOne && rotation.angle != 0

        // make a special case for when the rotation axis is aligned with z and the camera axis is aligned with z as well
        if axisIsAlignedWithCameraAxis, axisIsAlignedWithZ {
            drawWithArc(in: context)
        } else {
            drawWithPoints(in: context)
        }
    }

    private func drawWithArc(in context: RenderContext) {
        // make sure the arc makes the shortest arc

        let endPoint = pivot + rotation.act(point - pivot)
        let newRotation = Quat(from: point - pivot,
                               to: endPoint - pivot)

        let shortestAngle = (point - pivot).angleBetween(and: endPoint - pivot, around: Vector(0, 0, 1))

        let axis: Vector
        if shortestAngle <= 0 {
            axis = Vector(0, 0, -1)
        } else if shortestAngle == .pi {
            axis = rotation.axis
        } else {
            axis = Vector(0, 0, 1)
        }

        // use axis orbit for this
        AxisOrbitCounterClockwise(pivot: pivot,
                                  point: point,
                                  angle: abs(shortestAngle),
                                  axis: axis).drawPartOfPath(in: context)
    }

    private func drawWithPoints(in context: RenderContext) {
        let lever = point - pivot

        context.renderTarget.move(to: context.transform(point))
        let arcLength = rotation.angle * lever.length
        if arcLength > 0 {
            for arcDistance in stride(from: 0.0, through: arcLength, by: arcResolutuon) {
                let t = arcDistance / arcLength
                let rot = simd_slerp(.identity, rotation, t)
                let drawPoint = (pivot + rot.act(lever))
                context.renderTarget.addLine(to: context.transform(drawPoint))
            }
            let drawPoint = (pivot + rotation.act(lever))
            context.renderTarget.addLine(to: context.transform(drawPoint))
        }
    }
}
