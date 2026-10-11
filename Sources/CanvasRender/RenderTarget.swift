import CoreGraphics
import CoreText
import Foundation
import SwiftUI

public protocol RenderTarget {
    func addLine(to point: CGPoint)
    func move(to point: CGPoint)
    func beginPath(id: String?)
    func strokePath()
    func fillPath()
    func closePath()
    func setLineDash(phase: CGFloat, lengths: [CGFloat])
    func setStrokeColor(_ color: CGColor)
    func setLineWidth(_ width: CGFloat)
    func text(_ string: String, position: CGPoint, size: CGFloat)
    func arc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, counterClockwise: Bool)
    func addComment(_ string: String)
    func circle(center: CGPoint, radius: CGFloat)
}

public extension RenderTarget {
    func beginPath() {
        beginPath(id: nil)
    }
}

class GraphicsContextRenderTarget: RenderTarget {
    private let context: GraphicsContext

    private var currentPath: SwiftUI.Path?
    private var currentPathId: String?
    private var currentStrokeColor: Color = .black
    private var currentStrokeStyle = StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)

    init(context: GraphicsContext) {
        self.context = context
    }

    func beginPath(id: String?) {
        self.currentPath = SwiftUI.Path()
        self.currentPathId = id
    }

    func strokePath() {
        guard let currentPath else {
            return
        }
        context.stroke(currentPath, with: .color(currentStrokeColor), style: currentStrokeStyle)
        self.currentPath = nil
    }

    func fillPath() {
        guard let currentPath else {
            return
        }

        context.fill(currentPath, with: .color(currentStrokeColor))
        self.currentPath = nil
    }

    func addLine(to point: CGPoint) {
        var path = self.currentPath ?? SwiftUI.Path()
        // without a current point a line starts the subpath, like in the other targets
        if path.currentPoint == nil {
            path.move(to: point)
        } else {
            path.addLine(to: point)
        }
        self.currentPath = path
    }

    func move(to point: CGPoint) {
        var path = self.currentPath ?? SwiftUI.Path()
        path.move(to: point)
        self.currentPath = path
    }

    func closePath() {
        var path = self.currentPath ?? SwiftUI.Path()
        path.closeSubpath()
        self.currentPath = path
    }

    func arc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, counterClockwise: Bool) {
        var path = self.currentPath ?? SwiftUI.Path()

        path.addArc(center: center,
                    radius: radius,
                    startAngle: Angle(radians: startAngle),
                    endAngle: Angle(radians: endAngle),
                    clockwise: !counterClockwise)

        self.currentPath = path
    }

    public func circle(center: CGPoint, radius: CGFloat) {
        let startPos = CGPoint(x: center.x + radius,
                               y: center.y)

        var path = self.currentPath ?? SwiftUI.Path()
        path.addEllipse(in: CGRect(x: center.x - radius,
                                   y: center.y - radius,
                                   width: radius * 2,
                                   height: radius * 2))
        self.currentPath = path

        self.move(to: startPos)
    }

    func addComment(_ string: String) {
        // no op
    }

    func setLineDash(phase: CGFloat, lengths: [CGFloat]) {
        self.currentStrokeStyle = StrokeStyle(lineWidth: currentStrokeStyle.lineWidth,
                                              lineCap: currentStrokeStyle.lineCap,
                                              lineJoin: currentStrokeStyle.lineJoin,
                                              miterLimit: currentStrokeStyle.miterLimit,
                                              dash: lengths,
                                              dashPhase: phase)
    }

    func setStrokeColor(_ color: CGColor) {
        self.currentStrokeColor = SwiftUI.Color(cgColor: color)
    }

    func setLineWidth(_ width: CGFloat) {
        self.currentStrokeStyle = StrokeStyle(lineWidth: width,
                                              lineCap: currentStrokeStyle.lineCap,
                                              lineJoin: currentStrokeStyle.lineJoin,
                                              miterLimit: currentStrokeStyle.miterLimit,
                                              dash: currentStrokeStyle.dash,
                                              dashPhase: currentStrokeStyle.dashPhase)
    }

    func text(_ string: String, position: CGPoint, size: CGFloat) {
        let text = SwiftUI.Text(verbatim: string).font(.system(size: size))
        let resolvedText = context.resolve(text)

        context.draw(text, at: position, anchor: .bottomLeading)
    }
}

class CGContextRenderTarget: RenderTarget {
    private let cgContext: CGContext

    init(cgContext: CGContext) {
        self.cgContext = cgContext
    }

    func addLine(to point: CGPoint) {
        // without a current point a line starts the subpath, like in the other targets
        if cgContext.isPathEmpty {
            cgContext.move(to: point)
        } else {
            cgContext.addLine(to: point)
        }
    }

    func move(to point: CGPoint) {
        cgContext.move(to: point)
    }

    func beginPath(id: String?) {
        cgContext.beginPath()
    }

    func strokePath() {
        cgContext.strokePath()
    }

    func closePath() {
        cgContext.closePath()
    }

    func setLineDash(phase: CGFloat, lengths: [CGFloat]) {
        cgContext.setLineDash(phase: phase, lengths: lengths)
    }

    func setStrokeColor(_ color: CGColor) {
        cgContext.setStrokeColor(color)
    }

    func setLineWidth(_ width: CGFloat) {
        cgContext.setLineWidth(width)
    }

    public func arc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, counterClockwise: Bool = true) {
        cgContext.addArc(center: center,
                         radius: radius,
                         startAngle: startAngle,
                         endAngle: endAngle,
                         clockwise: !counterClockwise)

    }

    public func fillPath() {
        cgContext.fillPath(using: .evenOdd)
    }

    public func circle(center: CGPoint, radius: CGFloat) {
        let startPos = CGPoint(x: center.x + radius,
                               y: center.y)

        cgContext.addEllipse(in: CGRect(x: center.x - radius,
                                        y: center.y - radius,
                                        width: radius * 2,
                                        height: radius * 2))

        cgContext.move(to: startPos)
    }

    public func text(_ string: String, position: CGPoint, size: CGFloat) {
        let context = cgContext
        context.saveGState()

        let myfont = CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let attributes = [NSAttributedString.Key.font: myfont]
        let attributedString = NSAttributedString(string: string, attributes: attributes)

        // Flip
        // context.translateBy(x: 0, y: self.frame.size.height)
        // context.scaleBy(x: 1, y: -1)
        // context.translateBy(x: 100, y: 100)

//        context.concatenate(translateTransform)
//        context.concatenate(zoomTransform)
//        context.concatenate(flipVerticalTransform)
//
//        let transformedPosition = position
//            .applying(zoomTransform.inverted())
//            .applying(translateTransform.inverted())
//            .applying(flipVerticalTransform.inverted())

        string.draw(at: position, withAttributes: attributes)

        context.restoreGState()
    }

    public func addComment(_ string: String) {
    }
}
