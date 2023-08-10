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

        context.renderTarget.beginPath()
        context.renderTarget.move(to: CGPoint(x: center.x + cos(0.0) * radius , y: center.y + sin(0.0) * radius))
        for angle in stride(from: 0, through: .pi * 2.0, by: .pi * 2.0 / 100) {
            context.renderTarget.addLine(to: CGPoint(x: center.x + cos(angle) * radius , y: center.y + sin(angle) * radius))
        }
        //context.renderTarget.addArc(center: transformedCenter, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        context.renderTarget.closePath()
        context.renderTarget.strokePath()
    }
}
