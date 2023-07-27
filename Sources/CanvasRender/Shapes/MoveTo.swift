import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct MoveTo: PartOfPath {
    let point: Vector

    public init(_ point: Vector) {
        self.point = point
    }

    public func drawPartOfPath(in context: RenderContext) {
        let cgPoint = context.transform(point)
        context.cgContext.move(to: cgPoint)
    }
}
