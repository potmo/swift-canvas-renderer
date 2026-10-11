import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct Path: DrawableShape, PartOfPath {
    private let builder: () -> [any PartOfPath]
    private let closed: Bool
    private let filled: Bool
    private let id: String?

    public init(closed: Bool = false, filled: Bool = false, id: String? = nil, @PathBuilder _ builder: @escaping () -> [any PartOfPath]) {
        self.builder = builder
        self.closed = closed
        self.filled = filled
        self.id = id
    }

    public init(closed: Bool = false, points: [Vector], filled: Bool = false) {
        self.init(closed: closed, filled: filled) {
            if let startPoint = points.first {
                MoveTo(startPoint)

                for point in points.dropFirst() {
                    LineTo(point)
                }
            }
        }
    }

    public func drawPartOfPath(in context: RenderContext) {
        let parts = builder()
        for part in parts {
            part.drawPartOfPath(in: context)
        }
        if closed {
            context.renderTarget.closePath()
        }
    }

    public func draw(in context: RenderContext) {
        context.renderTarget.beginPath(id: id)
        self.drawPartOfPath(in: context)
        if filled {
            context.renderTarget.fillPath()
        } else {
            context.renderTarget.strokePath()
        }
    }
}
