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

        if vector2d.length == 0 {
            return
        }

        let perp = vector.arbitraryOrthogonal //vector.normalized.cross(-context.transform3d.cameraDirection).normalized

        if perp.length.isNaN {
            return
        }

        // let up = Vector(0, 0, 1)
        /*
         if vector.normalized.dot(up) == 1.0 {
             perp = vector.normalized.cross(Vector(1, 0, 0))
         } else {
             perp = vector.normalized.cross(up)
         }
          */

        let arrowSide = vector.normalized.scaled(by: wingLengths).rotated(by: Quat(angle: 170.degreesToRadians, axis: perp))

        let sides = stride(from: 0, to: .pi * 2, by: .pi * 2 / 4).map{ angle in
            return arrowSide.rotated(by: Quat(angle: angle, axis: vector.normalized))
        }
        //let arrowRightSide = vector.normalized.scaled(by: wingLengths).rotated(by: Quat(angle: -170.degreesToRadians, axis: perp))

        Path {
            MoveTo(origo)
            for side in sides {
                LineTo(origo + vector)
                LineTo(origo + vector + side)
            }
        }.draw(in: context)

        /*
                let base = context.transform(origo)
                let tip2d = origo + vector2d
                let arrowLeftSide2d = arrowLeftSide.xy
                let arrowRightSide2d = arrowRightSide.xy

                context.cgContext.beginPath()
                context.cgContext.move(to: base.cgPoint.applying(context.transform2d))
                context.cgContext.addLine(to: tip2d.cgPoint.applying(context.transform2d))
                context.cgContext.addLine(to: (tip2d + arrowRightSide2d).cgPoint.applying(context.transform2d))
                context.cgContext.move(to: tip2d.cgPoint.applying(context.transform2d))
                context.cgContext.addLine(to: (tip2d + arrowLeftSide2d).cgPoint.applying(context.transform2d))
                context.cgContext.strokePath()
         */

        // LineSection(from: origo, to: origo + vector).draw(in: context)
    }
}
