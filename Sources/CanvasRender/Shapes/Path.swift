import CoreGraphics
import Foundation
import simd
import SwiftUI


public struct Path: DrawableShape {
    private let parts: [any PartOfPath]
    private let closed: Bool

    public init(closed: Bool = false, @PathBuilder _ builder: () -> [any PartOfPath]) {
        self.parts = builder()
        self.closed = closed
    }

    public init(closed: Bool = false, points: [Vector2D]) {
        self.init(closed: closed) {
            if let startPoint = points.first {
                MoveTo(startPoint)

                for point in points.dropFirst() {
                    LineTo(point)
                }
            }
        }
    }

    public func draw(in context: CGContext, using transform: CGAffineTransform) {
        context.beginPath()
        for part in parts {
            part.drawPartOfPath(in: context, using: transform)
        }
        if closed {
            context.closePath()
        }
        context.strokePath()
    }
}
