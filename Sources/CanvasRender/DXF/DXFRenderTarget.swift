import CoreGraphics
import Foundation

/// Collects stroked geometry and writes it as a DXF file (or a PDF), without any external tools.
///
/// - Paths follow CoreGraphics semantics: geometry is committed when the path is stroked or filled, with
///   the color and dash pattern current at that moment; `closePath` closes the subpath and an arc that
///   doesn't start at the current point is connected to it with a line.
/// - Segments of the same style whose end points meet (within `joinTolerance`) are joined into polylines
///   with true arcs (bulges). Full circles become DXF CIRCLEs.
/// - Every style (color + dash pattern) gets its own layer, colored with the nearest AutoCAD color.
/// - Line widths and text are not exported.
public final class DXFRenderTarget: RenderTarget {
    public static let joinTolerance: CGFloat = 0.0001
    /// Lines shorter than this are dropped.
    static let minimumLength: CGFloat = 1e-7

    private var style = DXFStyle(color: .black)
    private var currentPoint: CGPoint?
    private var subpathStart: CGPoint?
    private var subpath: [DXFSegment] = []
    private var pendingSubpaths: [(segments: [DXFSegment], closed: Bool)] = []
    private var pendingCircles: [(center: CGPoint, radius: CGFloat)] = []

    private var joiner = PolylineJoiner(tolerance: DXFRenderTarget.joinTolerance)
    public private(set) var circles: [DXFCircle] = []

    public init() {}

    /// Everything exported so far: closed polylines first, then open ones, in drawing order.
    public var polylines: [DXFPolyline] {
        joiner.closed + joiner.open
    }

    /// Geometry drawn after this call is never joined with geometry drawn before it.
    public func finishGroup() {
        joiner.startNewGroup()
    }

    @available(*, deprecated, renamed: "finishGroup()")
    public func makeCurrentOpenNodesImmutable() {
        finishGroup()
    }

    /// The drawing as a DXF R2000 file in millimeters (one canvas unit is one millimeter).
    public func dxf() -> String {
        DXFWriter(polylines: polylines, circles: circles).document()
    }

    /// The drawing as a single-page PDF at 1:1 scale (one canvas unit is one millimeter), with `margin`
    /// millimeters around it.
    public func pdf(margin: CGFloat = 10, lineWidth: CGFloat = 0.2) -> Data {
        PDFWriter(polylines: polylines, circles: circles).document(margin: margin, lineWidth: lineWidth)
    }

    // MARK: - RenderTarget

    public func beginPath(id: String?) {
        // like CoreGraphics, a path that was never stroked or filled is discarded
        subpath = []
        pendingSubpaths = []
        pendingCircles = []
        currentPoint = nil
        subpathStart = nil
    }

    public func move(to point: CGPoint) {
        guard point.isFinite else {
            return
        }
        finishSubpath(closed: false)
        currentPoint = point
        subpathStart = point
    }

    public func addLine(to point: CGPoint) {
        guard point.isFinite else {
            // a DXF file can't contain it; leave a gap like a move would
            finishSubpath(closed: false)
            currentPoint = nil
            return
        }
        guard let currentPoint else {
            move(to: point)
            return
        }
        // shorter is numerical noise, e.g. a zero-length line that didn't come out exactly zero
        if hypot(point.x - currentPoint.x, point.y - currentPoint.y) >= Self.minimumLength {
            subpath.append(.line(from: currentPoint, to: point))
        }
        self.currentPoint = point
    }

    public func arc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, counterClockwise: Bool) {
        var sweep = counterClockwise ? endAngle - startAngle : startAngle - endAngle
        sweep = sweep.truncatingRemainder(dividingBy: 2 * .pi)
        if sweep < 0 {
            sweep += 2 * .pi
        }
        if sweep == 0, startAngle != endAngle {
            sweep = 2 * .pi
        }
        if !counterClockwise {
            sweep = -sweep
        }

        guard center.isFinite, radius.isFinite, startAngle.isFinite, sweep.isFinite else {
            finishSubpath(closed: false)
            currentPoint = nil
            return
        }
        let arc = DXFSegment.arc(center: center, radius: radius, startAngle: startAngle, sweep: sweep)
        let start = arc.startPoint
        if let currentPoint {
            if hypot(currentPoint.x - start.x, currentPoint.y - start.y) >= Self.joinTolerance {
                subpath.append(.line(from: currentPoint, to: start))
            }
        } else {
            subpathStart = start
        }
        if radius > 0, sweep != 0 {
            subpath.append(arc)
        }
        currentPoint = arc.endPoint
    }

    public func circle(center: CGPoint, radius: CGFloat) {
        guard center.isFinite, radius.isFinite else {
            return
        }
        finishSubpath(closed: false)
        pendingCircles.append((center, radius))
        // like CGContext.addEllipse, the current point ends up at the rightmost point
        currentPoint = CGPoint(x: center.x + radius, y: center.y)
        subpathStart = currentPoint
    }

    public func closePath() {
        guard let subpathStart, let currentPoint else {
            return
        }
        if hypot(currentPoint.x - subpathStart.x, currentPoint.y - subpathStart.y) >= Self.joinTolerance {
            subpath.append(.line(from: currentPoint, to: subpathStart))
        }
        finishSubpath(closed: true)
        self.currentPoint = subpathStart
    }

    public func strokePath() {
        commitPath()
    }

    public func fillPath() {
        commitPath()
    }

    public func setLineDash(phase: CGFloat, lengths: [CGFloat]) {
        style.dash = lengths.map { Double($0) }
    }

    public func setStrokeColor(_ color: CGColor) {
        style.color = CanvasColor(color)
    }

    public func setLineWidth(_ width: CGFloat) {}

    public func text(_ string: String, position: CGPoint, size: CGFloat) {}

    public func addComment(_ string: String) {}

    // MARK: - Paths

    private func finishSubpath(closed: Bool) {
        if !subpath.isEmpty {
            pendingSubpaths.append((subpath, closed))
        }
        subpath = []
    }

    private func commitPath() {
        finishSubpath(closed: false)
        for (segments, closed) in pendingSubpaths {
            commit(segments, closed: closed)
        }
        for (center, radius) in pendingCircles where radius > 0 {
            circles.append(DXFCircle(style: style, center: center, radius: radius))
        }
        pendingSubpaths = []
        pendingCircles = []
        currentPoint = nil
        subpathStart = nil
    }

    private func commit(_ segments: [DXFSegment], closed: Bool) {
        if segments.count == 1, case let .arc(center, radius, _, sweep) = segments[0], abs(sweep) >= 2 * .pi - 1e-9 {
            circles.append(DXFCircle(style: style, center: center, radius: radius))
            return
        }
        let first = segments[0].startPoint
        let last = segments[segments.count - 1].endPoint
        if closed || (segments.count > 1 && hypot(first.x - last.x, first.y - last.y) < Self.joinTolerance) {
            joiner.addClosed(segments, style: style)
        } else {
            joiner.addOpen(segments, style: style)
        }
    }
}

private extension CGPoint {
    var isFinite: Bool {
        x.isFinite && y.isFinite
    }
}

@available(*, deprecated, renamed: "DXFRenderTarget")
public typealias DXFLWLineRenderTarget = DXFRenderTarget

extension CanvasColor {
    /// The RGBA components of a color, converted to sRGB if needed.
    init(_ color: CGColor) {
        let components: [CGFloat]
        if color.colorSpace?.model == .rgb, let rgb = color.components, rgb.count == 4 {
            components = rgb
        } else if color.colorSpace?.model == .monochrome, let gray = color.components, gray.count == 2 {
            components = [gray[0], gray[0], gray[0], gray[1]]
        } else if let srgb = CGColorSpace(name: CGColorSpace.sRGB),
                  let converted = color.converted(to: srgb, intent: .defaultIntent, options: nil)?.components,
                  converted.count == 4 {
            components = converted
        } else {
            components = [0, 0, 0, 1]
        }
        self.init(Double(components[0]), Double(components[1]), Double(components[2]), Double(components[3]))
    }
}
