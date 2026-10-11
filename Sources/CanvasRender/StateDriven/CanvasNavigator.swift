import CoreGraphics
import Foundation

/// Lets callers drive the view transform of a `CanvasView`, e.g. from a button.
@MainActor
public final class CanvasNavigator {
    weak var canvas: CanvasNavigable?

    public init() {}

    /// Zooms and pans so everything drawn fits in the canvas.
    public func frameAll() {
        canvas?.frameAll()
    }
}

@MainActor
protocol CanvasNavigable: AnyObject {
    func frameAll()
}

/// Render target that draws nothing and only records the bounding box of everything drawn.
final class BoundsRenderTarget: RenderTarget {
    private(set) var bounds: CGRect = .null

    private func include(_ point: CGPoint) {
        bounds = bounds.union(CGRect(origin: point, size: .zero))
    }

    private func include(center: CGPoint, radius: CGFloat) {
        bounds = bounds.union(CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    }

    func addLine(to point: CGPoint) { include(point) }
    func move(to point: CGPoint) { include(point) }
    func beginPath(id: String?) {}
    func strokePath() {}
    func fillPath() {}
    func closePath() {}
    func setLineDash(phase: CGFloat, lengths: [CGFloat]) {}
    func setStrokeColor(_ color: CGColor) {}
    func setLineWidth(_ width: CGFloat) {}
    func text(_ string: String, position: CGPoint, size: CGFloat) { include(position) }
    func arc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, counterClockwise: Bool) {
        include(center: center, radius: radius)
    }
    func addComment(_ string: String) {}
    func circle(center: CGPoint, radius: CGFloat) { include(center: center, radius: radius) }
}
