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
        /*
         let wingLengths = vector.length.scaled(by: 0.15)

         // convert to xy plane
         let vector2d = context.transform3d.apply(point: vector)

         if vector2d.length == 0 {
             return
         }

         let arrowLeftSide = vector.normalized.scaled(by: wingLengths).rotated(by: Quat(angle: 170.degreesToRadians, axis: Vector(0, 0, 1)))
         let arrowRightSide = vector.normalized.scaled(by: wingLengths).rotated(by: Quat(angle: -170.degreesToRadians, axis: Vector(0, 0, 1)))

         let base = context.transform(origo)
         let tip2d = origo + vector2d
         let arrowLeftSide2d = arrowLeftSide.xy
         let arrowRightSide2d = arrowRightSide.xy

         // FIXME: maybe use this with path and somehow transform the wings to always face the camera?
         context.cgContext.beginPath()
         context.cgContext.move(to: base.cgPoint.applying(context.transform2d))
         context.cgContext.addLine(to: tip2d.cgPoint.applying(context.transform2d))
         context.cgContext.addLine(to: (tip2d + arrowRightSide2d).cgPoint.applying(context.transform2d))
         context.cgContext.move(to: tip2d.cgPoint.applying(context.transform2d))
         context.cgContext.addLine(to: (tip2d + arrowLeftSide2d).cgPoint.applying(context.transform2d))
         context.cgContext.strokePath()
         */
        LineSection(from: origo, to: origo + vector).draw(in: context)
    }
}
