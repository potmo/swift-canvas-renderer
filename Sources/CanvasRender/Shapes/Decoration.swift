import CoreGraphics
import Foundation
import simd
import SwiftUI


public struct Decoration: DrawableShape {
    let color: Color?
    let lineStyle: LineStyle?
    let lineWidth: Double?
    let shapes: [DrawableShape]

    public init(color: Color? = nil, lineStyle: LineStyle? = nil, lineWidth: Double? = nil, @CanvasBuilder _ builder: () -> [DrawableShape]) {
        self.color = color
        self.lineStyle = lineStyle
        self.shapes = builder()
        self.lineWidth = lineWidth
    }

    public func draw(in context: CGContext, using transform: CGAffineTransform) {
        context.saveGState()

        if let lineStyle {
            switch lineStyle {
            case .solid:
                context.setLineDash(phase: 0, lengths: [])
            case let .dashed(phase, lengths):
                context.setLineDash(phase: CGFloat(phase), lengths: lengths.map { CGFloat($0) })
            }
        }

        if let color {
            context.setStrokeColor(NSColor(color).cgColor)
        }

        if let lineWidth {
            context.setLineWidth(CGFloat(lineWidth))
        }

        for shape in shapes {
            shape.draw(in: context, using: transform)
        }
        context.restoreGState()
    }

    public enum LineStyle {
        case solid
        case dashed(phase: Double = 2, lengths: [Double] = [2, 2])
    }
}
