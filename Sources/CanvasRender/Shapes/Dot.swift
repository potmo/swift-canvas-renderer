import CoreGraphics
import Foundation
import simd
import SwiftUI


public struct Dot: DrawableShape {
    let at: simd_double2

    public init(at: simd_double2) {
        self.at = at
    }

    public func draw(in context: CGContext, using transform: CGAffineTransform) {
        let pos = CGPoint(x: at.x, y: at.y).applying(transform)
        // compute the x-scaling bit of the transform
        // let radius = 5 * sqrt(transform.a * transform.a + transform.c * transform.c)

        context.beginPath()
        context.addArc(center: pos,
                       radius: 2,
                       startAngle: 0,
                       endAngle: .pi * 2,
                       clockwise: true)
        context.strokePath()
    }
}
