import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct LineTo: PartOfPath {
    let point: Vector

    public init(_ point: simd_double3) {
        self.point = point
    }

    public func drawPartOfPath(in context: RenderContext) {
        let cgPoint = context.transform(point)
        context.cgContext.addLine(to: cgPoint)
    }
}
