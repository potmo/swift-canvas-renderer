import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct Comment: PartOfPath, DrawableShape {
    let string: String
    public init(_ string: String) {
        self.string = string
    }

    public func drawPartOfPath(in context: RenderContext) {
        context.renderTarget.addComment(string)
    }

    public func draw(in context: RenderContext) {
        self.drawPartOfPath(in: context)
    }
}
