import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct LineSection: DrawableShape, PartOfPath {
    let from: Vector
    let to: Vector

    public init(from: simd_double3, to: simd_double3) {
        self.from = from
        self.to = to
    }

    public func drawPartOfPath(in context: RenderContext) {
        context.renderTarget.move(to: context.transform(from))
        context.renderTarget.addLine(to: context.transform(to))
    }

    public func draw(in context: RenderContext) {
        context.renderTarget.beginPath()
        drawPartOfPath(in: context)
        context.renderTarget.strokePath()
    }
}
