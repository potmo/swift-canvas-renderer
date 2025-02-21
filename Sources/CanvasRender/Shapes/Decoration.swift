import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct Decoration: DrawableShape {
    let color: CanvasColor?
    let lineStyle: LineStyle?
    let lineWidth: Double?
    @CanvasBuilder let builder: () -> [DrawableShape]
    let hidden: Bool?

    public init(color: CanvasColor? = nil, lineStyle: LineStyle? = nil, lineWidth: Double? = nil, hidden: Bool? = false, @CanvasBuilder _ builder: @escaping () -> [DrawableShape]) {
        self.color = color
        self.lineStyle = lineStyle
        self.builder = builder
        self.lineWidth = lineWidth
        self.hidden = hidden
    }

    public func draw(in context: RenderContext) {

        let shapes = builder()
        
        // set line style
        let resetLineStyle: LineStyle?
        if let lineStyle, context.lineStyle != lineStyle {
            switch lineStyle {
            case .solid:
                context.renderTarget.setLineDash(phase: 0, lengths: [])
            case let .dashed(phase, lengths):
                context.renderTarget.setLineDash(phase: CGFloat(phase), lengths: lengths.map { CGFloat($0) })
            }

            resetLineStyle = context.lineStyle
        } else {
            resetLineStyle = nil
        }

        // set color
        let resetColor: CanvasColor?
        if let color, context.color != color {
            context.renderTarget.setStrokeColor(color.cgColor)
            resetColor = context.color
        } else {
            resetColor = nil
        }

        let resetLineWidth: Double?
        if let lineWidth, context.lineWidth != lineWidth {
            context.renderTarget.setLineWidth(CGFloat(lineWidth))
            resetLineWidth = context.lineWidth
        } else {
            resetLineWidth = nil
        }

        let newContext = RenderContext(canvasSize: context.canvasSize,
                                       renderTarget: context.renderTarget,
                                       color: color ?? context.color,
                                       lineWidth: lineWidth ?? context.lineWidth,
                                       lineStyle: lineStyle ?? context.lineStyle,
                                       transform2d: context.transform2d,
                                       transform3d: context.transform3d)

        // only draw if non hidden
        let isViewHidden = hidden ?? false
        if !isViewHidden {
            for shape in shapes {
                shape.draw(in: newContext)
            }
        }

        // reset color
        if let resetColor {
            context.renderTarget.setStrokeColor(resetColor.cgColor)
        }

        // reset linestyle
        if let resetLineStyle {
            switch resetLineStyle {
            case .solid:
                context.renderTarget.setLineDash(phase: 0, lengths: [])
            case let .dashed(phase, lengths):
                context.renderTarget.setLineDash(phase: CGFloat(phase), lengths: lengths.map { CGFloat($0) })
            }
        }
    }

    public enum LineStyle: Equatable {
        case solid
        case dashed(phase: Double = 2, lengths: [Double] = [2, 2])

        public static var regularDash: LineStyle {
            return dashed(phase: 0, lengths: [2, 2])
        }

        public static var bendDash: LineStyle {
            return dashed(phase: 0, lengths: [5, 2])
        }
    }
}
