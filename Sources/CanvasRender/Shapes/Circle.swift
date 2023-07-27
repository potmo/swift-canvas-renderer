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
        // compute the x-scaling bit of the transform
        let transformedRadius = radius * sqrt(Double(context.transform2d.a * context.transform2d.a + context.transform2d.c * context.transform2d.c))

        let arc = Arc(center: center,
                      radius: transformedRadius,
                      startAngle: 0,
                      endAngle: .pi * 2)
        
        context.cgContext.beginPath()
        arc.drawPartOfPath(in: context)
        context.cgContext.closePath()
        context.cgContext.strokePath()
    }
}
