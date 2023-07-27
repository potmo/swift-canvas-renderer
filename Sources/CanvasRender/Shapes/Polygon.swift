import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct Polygon: DrawableShape {
    let path: Path
    public init(vertices: [Vector], closed: Bool = true) {
        guard let first = vertices.first else {
            self.path = Path {
            }
            return
        }

        path = Path(closed: closed) {
            MoveTo(first)
            for vertex in vertices.dropFirst() {
                LineTo(vertex)
            }
        }
    }

    public func draw(in context: RenderContext) {
        path.draw(in: context)
    }
}
