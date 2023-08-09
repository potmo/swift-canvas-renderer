import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct Arc: DrawableShape, PartOfPath {
    let center: Vector
    let radius: Double
    let startAngle: Double
    let endAngle: Double

    public init(center: simd_double3, radius: simd_double1, startAngle: simd_double1, endAngle: simd_double1) {
        self.center = center
        self.radius = radius
        self.startAngle = startAngle
        self.endAngle = endAngle
    }

    public func draw(in context: RenderContext) {
        context.cgContext.beginPath()
        self.drawPartOfPath(in: context)
        context.cgContext.strokePath()
    }

    public func drawPartOfPath(in context: RenderContext) {
        let orbit = Orbit(center: center,
                          radius: radius,
                          startAngle: startAngle,
                          endAngle: endAngle,
                          planeNormal: -context.transform3d.cameraDirection)

        let rotation = Quat(from: Vector(0, 1, 0), to: context.transform3d.cameraDirection)

        orbit.drawPartOfPath(in: context)
    }
}
