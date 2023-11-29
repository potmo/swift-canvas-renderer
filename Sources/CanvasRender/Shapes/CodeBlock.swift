import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct CodeBlock: PartOfPath, DrawableShape {
    private let block: () -> Void
    public init(_ block: @escaping () -> Void) {
        self.block = block
    }

    public func drawPartOfPath(in context: RenderContext) {
        block()
    }

    public func draw(in context: RenderContext) {
        block()
    }
}
