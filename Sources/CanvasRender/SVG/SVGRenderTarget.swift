import CoreGraphics
import Foundation

/// Renders to an SVG document.
///
/// The drawing space is y-up like every other target; the SVG is y-down, so y is negated. One canvas unit is
/// one SVG user unit, and the document's `viewBox` is fitted around everything drawn.
public class SVGRenderTarget: RenderTarget {
    private var currentPath: [SVGCommand]?
    private var currentPathId: String?
    private var currentPoint: CGPoint?
    private var subpathStart: CGPoint?
    private var svgContent = ""
    private var currentColor = "#000000"
    private var currentStrokeDash: String?
    private var currentStrokeWidth: CGFloat = 1
    private var bounds = CGRect.null

    public init() {}

    // MARK: - Document

    public var svg: String {
        let margin = currentStrokeWidth
        let box = bounds.isNull ? CGRect(x: 0, y: 0, width: 1, height: 1) : bounds.insetBy(dx: -margin, dy: -margin)
        let fmt = DecimalFormatting.decimal
        // the content is stored with y negated, so the box is mirrored too
        let viewBox = "\(fmt(box.minX)) \(fmt(-box.maxY)) \(fmt(box.width)) \(fmt(box.height))"
        return """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(fmt(box.width))" height="\(fmt(box.height))" viewBox="\(viewBox)" stroke-linecap="round" stroke-linejoin="round">
        \(svgContent)</svg>

        """
    }

    // MARK: - RenderTarget

    public func beginPath(id: String?) {
        currentPath = []
        currentPathId = id
        currentPoint = nil
        subpathStart = nil
    }

    public func move(to point: CGPoint) {
        guard point.x.isFinite, point.y.isFinite else {
            // SVG can't contain it; leave a gap
            currentPoint = nil
            return
        }
        currentPath?.append(.move(x: point.x, y: -point.y))
        currentPoint = point
        subpathStart = point
        include(point)
    }

    public func addLine(to point: CGPoint) {
        guard point.x.isFinite, point.y.isFinite else {
            currentPoint = nil
            return
        }
        guard currentPoint != nil else {
            move(to: point)
            return
        }
        currentPath?.append(.line(x: point.x, y: -point.y))
        currentPoint = point
        include(point)
    }

    public func closePath() {
        guard currentPath != nil else {
            return
        }
        currentPath?.append(.closePath)
        currentPoint = subpathStart
    }

    public func arc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, counterClockwise: Bool = true) {
        guard [center.x, center.y, radius, startAngle, endAngle].allSatisfy(\.isFinite) else {
            currentPoint = nil
            return
        }
        let start = CGPoint(x: center.x + cos(startAngle) * radius, y: center.y + sin(startAngle) * radius)
        let end = CGPoint(x: center.x + cos(endAngle) * radius, y: center.y + sin(endAngle) * radius)

        // like CoreGraphics: start a subpath at the arc's start, or draw a line to it from the current point
        if currentPoint == nil {
            move(to: start)
        } else if currentPoint != start {
            addLine(to: start)
        }

        var angleDelta = counterClockwise ? (endAngle - startAngle) : (startAngle - endAngle)
        angleDelta = angleDelta.truncatingRemainder(dividingBy: 2 * .pi)
        if angleDelta < 0 { angleDelta += 2 * .pi }
        if angleDelta < 0.0001 && startAngle != endAngle { angleDelta = 2 * .pi }

        // the y axis is flipped, so counterclockwise in the drawing is clockwise (sweep flag 0) in the SVG
        let sweepFlag = counterClockwise ? 0 : 1

        // Split arcs larger than π into two halves. This avoids SVG issues
        // where large arcs at small radii round start/end to the same point
        // (making the A command degenerate), and also handles full circles.
        if angleDelta > .pi {
            let halfDelta = angleDelta / 2
            let midAngle = counterClockwise ? (startAngle + halfDelta) : (startAngle - halfDelta)
            let midX = center.x + cos(midAngle) * radius
            let midY = center.y + sin(midAngle) * radius
            currentPath?.append(.arc(rx: radius, ry: radius, endX: midX, endY: -midY, largeArcFlag: 0, sweepFlag: sweepFlag))
            currentPath?.append(.arc(rx: radius, ry: radius, endX: end.x, endY: -end.y, largeArcFlag: 0, sweepFlag: sweepFlag))
        } else {
            currentPath?.append(.arc(rx: radius, ry: radius, endX: end.x, endY: -end.y, largeArcFlag: 0, sweepFlag: sweepFlag))
        }
        currentPoint = end
        // conservatively the whole circle
        include(CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    public func circle(center: CGPoint, radius: CGFloat) {
        guard center.x.isFinite, center.y.isFinite, radius.isFinite else {
            return
        }
        let fmt = DecimalFormatting.decimal
        svgContent += "<circle cx=\"\(fmt(center.x))\" cy=\"\(fmt(-center.y))\" r=\"\(fmt(radius))\"\(strokeAttributes) fill=\"none\" />\n"
        include(CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    public func setLineDash(phase: CGFloat, lengths: [CGFloat]) {
        if lengths.isEmpty {
            currentStrokeDash = nil
        } else {
            currentStrokeDash = lengths.map { DecimalFormatting.decimal($0) }.joined(separator: ",")
        }
    }

    public func setLineWidth(_ width: CGFloat) {
        currentStrokeWidth = width
    }

    public func setStrokeColor(_ color: CGColor) {
        let color = CanvasColor(color)
        currentColor = String(format: "#%02lX%02lX%02lX", lround(color.r * 255), lround(color.g * 255), lround(color.b * 255))
    }

    public func strokePath() {
        emitPath(paint: "\(strokeAttributes) fill=\"none\"")
    }

    public func fillPath() {
        emitPath(paint: " stroke=\"none\" fill=\"\(currentColor)\"")
    }

    public func text(_ string: String, position: CGPoint, size: CGFloat) {
        guard position.x.isFinite, position.y.isFinite else {
            return
        }
        let fmt = DecimalFormatting.decimal
        svgContent += "<text x=\"\(fmt(position.x))\" y=\"\(fmt(-position.y))\" font-size=\"\(fmt(size))\" fill=\"\(currentColor)\">\(Self.escaped(string))</text>\n"
        include(position)
    }

    public func addComment(_ string: String) {
        // "--" is not allowed inside an XML comment
        svgContent += "<!-- \(string.replacingOccurrences(of: "--", with: "- -")) -->\n"
    }

    // MARK: - Helpers

    private var strokeAttributes: String {
        var attributes = " stroke=\"\(currentColor)\" stroke-width=\"\(DecimalFormatting.decimal(currentStrokeWidth))\""
        if let currentStrokeDash {
            attributes += " stroke-dasharray=\"\(currentStrokeDash)\""
        }
        return attributes
    }

    private func emitPath(paint: String) {
        guard let currentPath, !currentPath.isEmpty else {
            return
        }
        let content = currentPath.map(\.string).joined(separator: " ")
        let id = currentPathId.map { " id=\"\(Self.escaped($0))\"" } ?? ""
        svgContent += "<path\(id) d=\"\(content)\"\(paint) />\n"
        // like CoreGraphics, drawing consumes the path
        self.currentPath = nil
        currentPoint = nil
        subpathStart = nil
    }

    private func include(_ point: CGPoint) {
        include(CGRect(origin: point, size: .zero))
    }

    private func include(_ rect: CGRect) {
        bounds = bounds.union(rect)
    }

    private static func escaped(_ string: String) -> String {
        string.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    enum SVGCommand {
        case move(x: Double, y: Double)
        case line(x: Double, y: Double)
        case arc(rx: Double, ry: Double, endX: Double, endY: Double, largeArcFlag: Int, sweepFlag: Int)
        case closePath

        var string: String {
            let fmt = DecimalFormatting.decimal
            switch self {
            case let .move(x, y):
                return "M\(fmt(x)) \(fmt(y))"
            case let .line(x, y):
                return "L\(fmt(x)) \(fmt(y))"
            case let .arc(rx, ry, endX, endY, largeArcFlag, sweepFlag):
                return "A\(fmt(rx)) \(fmt(ry)) 0 \(largeArcFlag) \(sweepFlag) \(fmt(endX)) \(fmt(endY))"
            case .closePath:
                return "Z"
            }
        }
    }
}
