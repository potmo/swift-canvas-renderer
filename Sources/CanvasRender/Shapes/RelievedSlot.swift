import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct RelievedSlot: DrawableShape, PartOfPath {
    private let start: Vector
    private let end: Vector
    private let width: Vector
    private let reliefDepth: Double
    private let reliefRadius: Double

    public init(start: Vector, end: Vector, width: Vector, reliefDepth: Double, reliefRadius: Double) {
        self.start = start
        self.end = end
        self.width = width
        self.reliefDepth = reliefDepth
        self.reliefRadius = reliefRadius
    }

    public func draw(in context: RenderContext) {
        context.renderTarget.beginPath()
        self.drawPartOfPath(in: context)
        context.renderTarget.strokePath()
    }

    public func drawPartOfPath(in context: RenderContext) {
        let dir = (end - start).normalized
        let perpDir = width.normalized
        let rotationAxis = perpDir.cross(dir)

        Path {
            MoveTo(start)
            LineTo(start + width + perpDir.scaled(by: reliefDepth))
            AxisOrbitCounterClockwise(pivot: start + width + perpDir.scaled(by: reliefDepth) + dir.scaled(by: reliefRadius),
                                      point: start + width + perpDir.scaled(by: reliefDepth),
                                      angle: .pi,
                                      axis: rotationAxis)
            LineTo(start + width + dir.scaled(by: reliefRadius * 2))
            LineTo(end + width - dir.scaled(by: reliefRadius * 2))
            LineTo(end + width - dir.scaled(by: reliefRadius * 2) + perpDir.scaled(by: reliefDepth))
            AxisOrbitCounterClockwise(pivot: end + width - dir.scaled(by: reliefRadius) + perpDir.scaled(by: reliefDepth),
                                      point: end + width - dir.scaled(by: reliefRadius * 2) + perpDir.scaled(by: reliefDepth),
                                      angle: .pi,
                                      axis: rotationAxis)
            LineTo(end - width - perpDir.scaled(by: reliefDepth))
            AxisOrbitCounterClockwise(pivot: end - width - perpDir.scaled(by: reliefDepth) - dir.scaled(by: reliefRadius),
                                      point: end - width - perpDir.scaled(by: reliefDepth),
                                      angle: .pi,
                                      axis: rotationAxis)
            LineTo(end - width - dir.scaled(by: reliefRadius * 2))
            LineTo(start - width + dir.scaled(by: reliefRadius * 2))
            LineTo(start - width + dir.scaled(by: reliefRadius * 2) - perpDir.scaled(by: reliefDepth))

            AxisOrbitCounterClockwise(pivot: start - width + dir.scaled(by: reliefRadius) - perpDir.scaled(by: reliefDepth),
                                      point: start - width + dir.scaled(by: reliefRadius * 2) - perpDir.scaled(by: reliefDepth),
                                      angle: .pi,
                                      axis: rotationAxis)

            LineTo(start)

        }.drawPartOfPath(in: context)
    }
}
