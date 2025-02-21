import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct CodeBlock: PartOfPath, DrawableShape {
    private let block: (_:RenderContext) -> Void
    public init(_ block: @escaping (_:RenderContext) -> Void) {
        self.block = block
    }

    public func drawPartOfPath(in context: RenderContext) {
        block(context)
    }

    public func draw(in context: RenderContext) {
        block(context)
    }
}
