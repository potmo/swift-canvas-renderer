import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct TextString: DrawableShape {
    let center: Vector
    let text: String
    let size: Double

    public init(center: Vector, text: String, size: Double) {
        self.center = center
        self.text = text
        self.size = size
    }

    public func draw(in context: RenderContext) {
        let transformedCenter = context.transform(center)

        context.renderTarget.text(text, position: transformedCenter, size: CGFloat(size))
    }
}
