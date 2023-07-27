import CoreGraphics
import Foundation
import simd
import SwiftUI

public protocol DrawableShape {
    func draw(in context: RenderContext)
}

public protocol DrawableObject: DrawableShape {
    @CanvasBuilder var shapes: [any DrawableShape] { get }
}

public extension DrawableObject {
    func draw(in context: RenderContext) {
        for shape in self.shapes {
            shape.draw(in: context)
        }
    }
}

extension Array: DrawableShape where Element: DrawableShape {
    public func draw(in context: RenderContext) {
        for shape in self {
            shape.draw(in: context)
        }
    }
}

public struct Shapes: DrawableShape {
    let shapes: [DrawableShape]
    public init(shapes: [DrawableShape]) {
        self.shapes = shapes
    }

    public func draw(in context: RenderContext) {
        for shape in shapes {
            shape.draw(in: context)
        }
    }
}

public extension CGContext {
    func move(to point: simd_double2, transform: CGAffineTransform) {
        self.move(to: point.cgPoint.applying(transform))
    }

    func addLine(to point: simd_double2, transform: CGAffineTransform) {
        self.addLine(to: point.cgPoint.applying(transform))
    }
}
