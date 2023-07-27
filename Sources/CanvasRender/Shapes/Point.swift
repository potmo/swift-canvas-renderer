import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct Point: DrawableShape {
    let point: Vector

    public init(_ point: Vector) {
        self.point = point
    }

    public func draw(in context: RenderContext) {
        let pos = context.transform(point)

        context.cgContext.beginPath()
        context.cgContext.addArc(center: pos,
                                 radius: 2,
                                 startAngle: 0,
                                 endAngle: .pi * 2,
                                 clockwise: true)
        context.cgContext.strokePath()
    }
}
