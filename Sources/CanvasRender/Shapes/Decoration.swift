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

    public func draw(in context: RenderContext) {
        // set line style
        let resetLineStyle: LineStyle?
        if let lineStyle, context.lineStyle != lineStyle {
            switch lineStyle {
            case .solid:
                context.cgContext.setLineDash(phase: 0, lengths: [])
            case let .dashed(phase, lengths):
                context.cgContext.setLineDash(phase: CGFloat(phase), lengths: lengths.map { CGFloat($0) })
            }

            resetLineStyle = context.lineStyle
        } else {
            resetLineStyle = nil
        }

        // set color
        let resetColor: Color?
        if let color, context.color != color {
            context.cgContext.setStrokeColor(NSColor(color).cgColor)
            resetColor = context.color
        } else {
            resetColor = nil
        }

        let resetLineWidth: Double?
        if let lineWidth, context.lineWidth != lineWidth {
            context.cgContext.setLineWidth(CGFloat(lineWidth))
            resetLineWidth = context.lineWidth
        } else {
            resetLineWidth = nil
        }

        let newContext = RenderContext(canvasSize: context.canvasSize,
                                       cgContext: context.cgContext,
                                       color: color ?? context.color,
                                       lineWidth: lineWidth ?? context.lineWidth,
                                       lineStyle: lineStyle ?? context.lineStyle,
                                       transform2d: context.transform2d,
                                       transform3d: context.transform3d)

        for shape in shapes {
            shape.draw(in: newContext)
        }

        // reset color
        if let resetColor {
            context.cgContext.setStrokeColor(NSColor(resetColor).cgColor)
        }

        // reset linestyle
        if let resetLineStyle {
            switch resetLineStyle {
            case .solid:
                context.cgContext.setLineDash(phase: 0, lengths: [])
            case let .dashed(phase, lengths):
                context.cgContext.setLineDash(phase: CGFloat(phase), lengths: lengths.map { CGFloat($0) })
            }
        }
    }

    public enum LineStyle: Equatable {
        case solid
        case dashed(phase: Double = 2, lengths: [Double] = [2, 2])
    }
}
