import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct Circle: DrawableShape {
    let center: Vector
    let radius: Double

    public init(center: Vector, radius: Double) {
        self.center = center
        self.radius = radius
    }

    public func draw(in context: RenderContext) {
        let transformedCenter = context.transform(center)

        context.cgContext.beginPath()
        context.cgContext.addArc(center: transformedCenter, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        context.cgContext.closePath()
        context.cgContext.strokePath()
    }
}
