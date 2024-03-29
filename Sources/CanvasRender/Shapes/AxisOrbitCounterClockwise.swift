import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct AxisOrbitCounterClockwise: DrawableShape, PartOfPath {
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
        context.renderTarget.beginPath()
        drawPartOfPath(in: context)
        context.renderTarget.strokePath()
    }

    public func drawPartOfPath(in context: RenderContext) {
        let axisIsAlignedWithCameraAxis = context.transform(Vector(0, 0, 0)) == context.transform(Vector(0, 0, 1))
        let axisIsAlignedWithZ = abs(axis.dot(Vector(0, 0, 1))) >= 1.0 - .ulpOfOne

        // make a special case for when the rotation axis is aligned with z and the camera axis is aligned with z as well
        if axisIsAlignedWithCameraAxis, axisIsAlignedWithZ {
            drawWithArc(in: context)
        } else {
            drawWithPoints(in: context)
        }
    }

    private func drawWithArc(in context: RenderContext) {
        let lever = point - pivot

        // transform the positions to capture the camera transform without doing the matrix math
        let transformedPivot = context.transform(pivot)
        let transformedPoint = context.transform(point)

        let transformedLever = Vector(transformedPoint.x, transformedPoint.y, 0) - Vector(transformedPivot.x, transformedPivot.y, 0)
        let transformedRadius = transformedLever.length

        let startAngle = Vector(1, 0, 0).angleBetween(and: transformedLever, around: Vector(0, 0, 1))
        let endAngle = startAngle + angle

        // if the rotation axis is upside down then we have to flip things
        let fixedEndAngle: Double
        let fixedStartAngle: Double

        if axis.dot(Vector(0, 0, 1)) < 0 || angle < 0 {
            let delta = atan2(sin(endAngle - startAngle), cos(endAngle - startAngle))
            fixedEndAngle = startAngle
            fixedStartAngle = startAngle - delta

        } else {
            fixedEndAngle = endAngle
            fixedStartAngle = startAngle
        }

        // make sure the we draw a line to the start position first and end up at the end position
        let transformedStartPoint = context.transform(point)
        let transformedEndPoint = context.transform(pivot + Quat(angle: angle, axis: axis).act(lever))

        context.renderTarget.move(to: transformedStartPoint)

        if abs(angle) == .pi * 2 {
            context.renderTarget.circle(center: transformedPivot,
                                        radius: transformedRadius)
        } else {
            context.renderTarget.arc(center: transformedPivot,
                                     radius: transformedRadius,
                                     startAngle: fixedStartAngle,
                                     endAngle: fixedEndAngle,
                                     counterClockwise: true)
        }

        context.renderTarget.move(to: transformedEndPoint)
    }

    private func drawWithPoints(in context: RenderContext) {
        let lever = (point - pivot).normalized.scaled(by: radius)
        context.renderTarget.move(to: context.transform(point))

        let arcLength = abs(angle) * radius

        let clockwise = false

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
