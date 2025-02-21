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
        let lower = context.transform(Vector(0, 0, 0))
        let upper = context.transform(Vector(0, 0, 1))
        let lowerVector = Vector2D(x: lower.x, y: lower.y)
        let upperVector = Vector2D(x: upper.x, y: upper.y)
        let distance = simd_precise_distance(lowerVector, upperVector)

        let axisIsAlignedWithCameraAxis = distance <= 0.000001

        let axisIsAlignedWithZ = abs(axis.dot(Vector(0, 0, 1))) >= 0.9999999

        // make a special case for when the rotation axis is aligned with z and the camera axis is aligned with z as well
        if axisIsAlignedWithCameraAxis, axisIsAlignedWithZ {
            drawWithArc(in: context)
        } else {
          //  fatalError("This should not happen")
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
        let transformedStartPoint = context.transform(point)
        let transformedEndPoint = context.transform(pivot + Quat(angle: angle, axis: axis).act(lever))

        var startAngle: Double
        var endAngle: Double
        let newAxis = findNewAxis(in: context)

        if newAxis.z * axis.z < 0 {
            startAngle = Vector(1, 0, 0).angleBetween(and: transformedLever, around: Vector(0, 0, 1))
            endAngle = startAngle - angle
        } else {
            endAngle = Vector(1, 0, 0).angleBetween(and: transformedLever, around: Vector(0, 0, 1))
            startAngle = endAngle + angle
        }

        context.renderTarget.move(to: transformedStartPoint)

        if abs(angle) == .pi * 2 {
            context.renderTarget.circle(center: transformedPivot,
                                        radius: transformedRadius)
        } else {
            context.renderTarget.arc(center: transformedPivot,
                                     radius: transformedRadius,
                                     startAngle: endAngle,
                                     endAngle: startAngle,
                                     counterClockwise: true)
        }

        context.renderTarget.move(to: transformedEndPoint)
    }

    private func findNewAxis(in context: RenderContext) -> Vector {
        // We know that the axis is aligned with the z axis or the inverted z axis but offsets of flips might have occured so we need to compute the actual axis. Then we can get the cross product to figure out the new axis and see if it is flipped
        let northArrowTransformed = context.transform(Vector(0, 1, 0)).vector2D - context.transform(Vector(0, 0, 0)).vector2D
        let eastArrowTransformed = context.transform(Vector(1, 0, 0)).vector2D - context.transform(Vector(0, 0, 0)).vector2D
        return Vector(eastArrowTransformed.x, eastArrowTransformed.y, 0).normalized
            .cross(Vector(northArrowTransformed.x, northArrowTransformed.y, 0).normalized)
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
