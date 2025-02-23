import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct Arrow: DrawableShape {
    private let vector: Vector
    private let origo: Vector

    public init(vector: Vector, origo: Vector = [0, 0, 0]) {
        self.vector = vector
        self.origo = origo
    }

    public init(from: Vector, to: Vector) {
        self.init(vector: to - from, origo: from)
    }

    public func draw(in context: RenderContext) {
        let wingLengths = vector.length.scaled(by: 0.15)

        // convert to xy plane
        let vector2d = context.transform3d.apply(point: vector, canvasSize: context.canvasSize)

        if vector.length == 0 {
            return
        }

        if vector2d.length == 0 {
            return
        }

        let arrowRotation = Quat(from: Vector(0, 0, 1), to: vector.normalized)
        let wing = Vector(0, 0, wingLengths)
            .rotated(by: Quat(angle: 170.degreesToRadians, axis: Vector(0, 1, 0)))
            .rotated(by: arrowRotation)

        let sides = stride(from: 0, to: .pi * 2, by: .pi * 2 / 4).map { angle in
            return wing.rotated(by: Quat(angle: angle, axis: vector.normalized))
        }

        Path {
            MoveTo(origo)
            for side in sides {
                LineTo(origo + vector)
                LineTo(origo + vector + side)
            }
        }.draw(in: context)
    }
}
