import CoreGraphics
import Foundation
import simd
import SwiftUI


public struct Arrow: DrawableShape {
    private let vector: simd_double2
    private let origo: simd_double2
    private let magnitude: Double

    public init(vector: simd_double3, origo: simd_double3 = [0, 0, 0], plane: AxisPlane) {
        self.init(vector: plane.convert(vector), origo: plane.convert(origo), magnitude: vector.length)
    }

    public init(from: Vector, to: Vector, plane: AxisPlane) {
        self.init(vector: to - from, origo: from, plane: plane)
    }

    public init(vector: simd_double2, origo: simd_double2 = [0, 0]) {
        self.init(vector: vector, origo: origo, magnitude: vector.length)
    }

    private init(vector: simd_double2, origo: simd_double2, magnitude: Double) {
        self.vector = vector
        self.origo = origo
        self.magnitude = magnitude
    }

    public func draw(in context: CGContext, using transform: CGAffineTransform) {
        let vector = Vector(x: self.vector.x, y: self.vector.y, z: 0)

        if vector.length == 0 {
            return
        }

        let wingLengths = magnitude.scaled(by: 0.15)

        let arrowLeftSide = vector.normalized.scaled(by: wingLengths).rotated(by: Quat(angle: 170.degreesToRadians, axis: Vector(0, 0, 1)))
        let arrowRightSide = vector.normalized.scaled(by: wingLengths).rotated(by: Quat(angle: -170.degreesToRadians, axis: Vector(0, 0, 1)))

        Path {
            MoveTo(origo)
            LineTo(origo + vector.xy)
            LineTo(origo + (vector + arrowRightSide).xy)
            MoveTo(origo + vector.xy)
            LineTo(origo + (vector + arrowLeftSide).xy)
        }.draw(in: context, using: transform)
    }
}
