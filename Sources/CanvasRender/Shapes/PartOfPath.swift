import CoreGraphics
import Foundation
import simd
import SwiftUI

public protocol PartOfPath {
    func drawPartOfPath(in context: RenderContext)
}

extension [PartOfPath]: PartOfPath {
    public func drawPartOfPath(in context: RenderContext) {
        for part in self {
            part.drawPartOfPath(in: context)
        }
    }
}
