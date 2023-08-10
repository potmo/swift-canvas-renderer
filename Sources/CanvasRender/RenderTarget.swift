import CoreGraphics
import Foundation

public protocol RenderTarget {
    func addLine(to point: CGPoint)
    func move(to point: CGPoint)
    func beginPath()
    func strokePath()
    func closePath()
    func setLineDash(phase: CGFloat, lengths: [CGFloat])
    func setStrokeColor(_ color: CGColor)
    func setLineWidth(_ width: CGFloat)
}

extension CGContext: RenderTarget {
}
