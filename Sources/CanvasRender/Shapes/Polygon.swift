import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct Polygon: DrawableShape {
    let path: Path
    public init(vertices: [Vector], closed: Bool = true, renderPlane: AxisPlane) {
        guard let first = vertices.first else {
            self.path = Path {
            }
            return
        }

        path = Path(closed: closed) {
            MoveTo(first, plane: renderPlane)
            for vertex in vertices.dropFirst() {
                LineTo(vertex, plane: renderPlane)
            }
        }
    }

    public func draw(in context: CGContext, using transform: CGAffineTransform) {
        path.draw(in: context, using: transform)
    }
}
