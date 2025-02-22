import Cocoa
import simd
import SwiftUI

class Canvas<StateType: ObservableObject>: NSView {
    private var trackingArea: NSTrackingArea?

    private var zoomTransform: CGAffineTransform {
        return .identity.scaledBy(x: zoom, y: zoom)
    }

    private var translateTransform: CGAffineTransform {
        return .identity.translatedBy(x: translation.x, y: translation.y)
    }

    private let origoInUpperLeft = false

    private var flipVerticalTransform: CGAffineTransform {
        if origoInUpperLeft {
            return CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: self.frame.size.height)
        } else {
            return CGAffineTransform.identity
        }
    }

    private var mousePos: CGPoint? = nil
    @AppStorage("zoom_6") private var zoom = 1.0

    // workaround to make AppStorage store the translation (it cannot store complex types)
    @AppStorage("translationX_6") private var translationX: Double = 0
    @AppStorage("translationY_6") private var translationY: Double = 0

    private var translation: simd_double2 {
        set {
            self.translationX = newValue.x
            self.translationY = newValue.y
        }
        get {
            simd_double2(translationX, translationY)
        }
    }

    private let maker: any ShapeMaker<StateType>
    private let state: StateType
    private let renderTransform: RenderTransformer
    private let canvasSize: Vector2D

    init(state: StateType,
         maker: any ShapeMaker<StateType>,
         renderTransform: RenderTransformer,
         canvasSize: Vector2D) {
        self.maker = maker
        self.state = state
        self.renderTransform = renderTransform
        self.canvasSize = canvasSize
        super.init(frame: NSRect(x: 0, y: 0, width: canvasSize.x, height: canvasSize.y))
        self.wantsRestingTouches = false
        self.allowedTouchTypes = .indirect
        self.clipsToBounds = true
    }

    override init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let shapes = self.maker.shapes(from: state)

        guard let cgContext = NSGraphicsContext.current?.cgContext else {
            fatalError("not able to create context for drawing")
        }

        // flip y-axis so origin is in top left corner
        cgContext.concatenate(flipVerticalTransform)

        let transform = zoomTransform.concatenating(translateTransform)
        let renderTarget = CGContextRenderTarget(cgContext: cgContext)
        let context = RenderContext(canvasSize: Vector2D(frame.size.width, frame.size.height),
                                    renderTarget: renderTarget,
                                    transform2d: transform,
                                    transform3d: renderTransform)

        cgContext.setLineCap(.round)
        cgContext.setLineJoin(.round)
        cgContext.setStrokeColor(context.color.cgColor)
        cgContext.setLineWidth(context.lineWidth)

        shapes.forEach { $0.draw(in: context) }

        // draw shapes in input space
        // context.setStrokeColor(CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        // scence.forEach { $0.draw(in: context, using: .identity) }

        if let mousePos = mousePos {
            // draw mouse in screen space
            cgContext.setLineDash(phase: 0, lengths: [])
            cgContext.beginPath()
            cgContext.setStrokeColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
            cgContext.addArc(center: mousePos, radius: 5, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)
            cgContext.strokePath()
        }

        // draw frame
        cgContext.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.5))
        cgContext.beginPath()
        cgContext.move(to: CGPoint(x: 0, y: 0))
        cgContext.addLine(to: CGPoint(x: frame.size.width, y: 0))
        cgContext.addLine(to: CGPoint(x: frame.size.width, y: frame.size.height))
        cgContext.addLine(to: CGPoint(x: 0, y: frame.size.height))
        cgContext.closePath()
        cgContext.strokePath()
    }

    func drawText(context: CGContext, text: String, position: CGPoint) {
        context.saveGState()

        let myfont = CTFontCreateWithName("Helvetica" as CFString, 24, nil)
        let attributes = [NSAttributedString.Key.font: myfont]
        let attributedString = NSAttributedString(string: text, attributes: attributes)

        // calculate text frame
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let textFrame = CTFramesetterCreateFrame(framesetter,
                                                 CFRange(),
                                                 CGPath(rect: bounds, transform: nil),
                                                 nil)

        // Flip
        // context.translateBy(x: 0, y: self.frame.size.height)
        // context.scaleBy(x: 1, y: -1)
        // context.translateBy(x: 100, y: 100)

        context.concatenate(translateTransform)
        context.concatenate(zoomTransform)
        context.concatenate(flipVerticalTransform)

        let transformedPosition = position
            .applying(zoomTransform.inverted())
            .applying(translateTransform.inverted())
            .applying(flipVerticalTransform.inverted())
        // CTFrameDraw(textFrame, context)

        text.draw(at: transformedPosition, withAttributes: attributes)

        context.restoreGState()
    }

    func drawText2(context: CGContext, text: String, position: CGPoint) {
        context.saveGState()
        let color = CGColor.black
        let fontSize: CGFloat = 32
        // You can use the Font Book app to find the name
        let fontName = "Chalkboard" as CFString
        let font = CTFontCreateWithName(fontName, fontSize, nil)

        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let attributedString = NSAttributedString(string: text,
                                                  attributes: attributes)

        // Render
        let line = CTLineCreateWithAttributedString(attributedString)

        /* context.textPosition = CGPoint(x: position.x + margin,
         y: position.y + margin) */

        // context.concatenate(flipVerticalTransform)
        let positionTransformed = position.applying(flipVerticalTransform
            .concatenating(zoomTransform)
            .concatenating(translateTransform)
            .inverted())
        let positioningTransform = CGAffineTransform(translationX: positionTransformed.x,
                                                     y: positionTransformed.y)

        context.textMatrix = positioningTransform
            .concatenating(flipVerticalTransform)
            .concatenating(zoomTransform)
            .concatenating(translateTransform)

        CTLineDraw(line, context)

        context.textMatrix = .identity

        let apa = "cow"
        apa.draw(with: CGRect(x: 32, y: 32, width: 448, height: 448),
                 options: .usesLineFragmentOrigin,
                 attributes: attributes,
                 context: nil)

        context.restoreGState()
    }

    override func updateTrackingAreas() {
        if trackingArea != nil {
            self.removeTrackingArea(trackingArea!)
        }
        let options: NSTrackingArea.Options =
            [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow]

        trackingArea = NSTrackingArea(rect: self.bounds,
                                      options: options,
                                      owner: self,
                                      userInfo: nil)
        self.addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        let local = self.convert(event.locationInWindow, to: self).applying(flipVerticalTransform)
        mousePos = local
        setNeedsDisplay(self.bounds)
    }

    override func mouseExited(with event: NSEvent) {
        //        let local = self.convert(event.locationInWindow, to: self)
        //        print("mouse exited \(local.x) \(local.y)")
        mousePos = nil
        setNeedsDisplay(self.bounds)
    }

    override func mouseMoved(with event: NSEvent) {
        let local = self.convert(event.locationInWindow, to: self).applying(flipVerticalTransform)
        mousePos = local
        setNeedsDisplay(self.bounds)

        //        print("mouse moved \(local.x) \(local.y) delta: \(event.deltaX) \(event.deltaY)")
    }

    private var initialTouch: NSTouch?
    override func touchesBegan(with event: NSEvent) {
        let initialTouches = event.touches(matching: .touching, in: self)

        guard initialTouches.count == 2 else {
            return
        }

        guard let initialTouch = initialTouches.first else {
            return
        }

        self.initialTouch = initialTouch
    }

    override func touchesMoved(with event: NSEvent) {
        //        print("toches \(event.allTouches().count)")

        guard event.touches(matching: .touching, in: self).count == 2 else {
            return
        }

        guard let previousTouch = initialTouch else {
            return
        }

        guard let currentTouch = event.touches(matching: .touching, in: self).first(where: { $0.identity.isEqual(previousTouch.identity) }) else {
            return
        }

        let previousPos = CGPoint(x: previousTouch.normalizedPosition.x * previousTouch.deviceSize.width,
                                  y: previousTouch.normalizedPosition.y * previousTouch.deviceSize.height)

        let currentPos = CGPoint(x: currentTouch.normalizedPosition.x * currentTouch.deviceSize.width,
                                 y: currentTouch.normalizedPosition.y * currentTouch.deviceSize.height)

        let delta = CGPoint(x: previousPos.x - currentPos.x, y: previousPos.y - currentPos.y)

        if origoInUpperLeft {
            translation += [-delta.x, delta.y] * 2
        } else {
            translation += [-delta.x, -delta.y] * 2
        }

        self.initialTouch = currentTouch

        setNeedsDisplay(self.bounds)
    }

    override func mouseDown(with event: NSEvent) {
        let local = self.convert(event.locationInWindow, to: self).applying(flipVerticalTransform)
        self.mousePos = local
        setNeedsDisplay(self.bounds)
    }

    override func mouseUp(with event: NSEvent) {
        let local = self.convert(event.locationInWindow, to: self).applying(flipVerticalTransform)
        self.mousePos = local
    }

    override func magnify(with event: NSEvent) {
        let local = self.convert(event.locationInWindow, to: self).applying(flipVerticalTransform)
        let localInUnZoomedSpace = local.applying(zoomTransform.concatenating(translateTransform).inverted())

        let zoomFactor = 1 / (1 - event.magnification)

        self.zoom = zoom * zoomFactor

        let newTransform = CGAffineTransform(scaleX: zoom, y: zoom)
            .translatedBy(x: localInUnZoomedSpace.x, y: localInUnZoomedSpace.y)
            .scaledBy(x: zoomFactor, y: zoomFactor)
            .translatedBy(x: -localInUnZoomedSpace.x, y: -localInUnZoomedSpace.y)

        // put the transform part in the translation
        translation += [newTransform.tx, newTransform.ty]

        // put the scale part in zoom
        zoom = sqrt(Double(newTransform.a * newTransform.a + newTransform.c * newTransform.c))

        setNeedsDisplay(self.bounds)
    }

    override func rightMouseDragged(with event: NSEvent) {
        let local = self.convert(event.locationInWindow, to: self).applying(flipVerticalTransform)
        self.mousePos = local

        let delta = CGPoint(x: event.deltaX, y: event.deltaY)

        if origoInUpperLeft {
            translation += [-delta.x, delta.y]
        } else {
            translation += [delta.x, -delta.y]
        }

        setNeedsDisplay(self.bounds)
    }

    override func mouseDragged(with event: NSEvent) {
        let local = self.convert(event.locationInWindow, to: self).applying(flipVerticalTransform)
        self.mousePos = local

        let delta = CGPoint(x: event.deltaX, y: event.deltaY)

        if origoInUpperLeft {
            translation += [-delta.x, delta.y]
        } else {
            translation += [delta.x, -delta.y]
        }

        setNeedsDisplay(self.bounds)
    }

    override func scrollWheel(with event: NSEvent) {
        guard let mousePos else {
            return
        }

        // dont scroll with mouse pad, only mouse
        guard !event.hasPreciseScrollingDeltas else {
            return
        }

        let local = self.convert(mousePos, to: self).applying(flipVerticalTransform)
        let localInUnZoomedSpace = local.applying(zoomTransform.concatenating(translateTransform).inverted())

        let scrollValue = min(2.0, max(-2.0, event.scrollingDeltaY)) * 0.1
        let zoomFactor = 1 / (1 - scrollValue)

        self.zoom = zoom * zoomFactor

        let newTransform = CGAffineTransform(scaleX: zoom, y: zoom)
            .translatedBy(x: localInUnZoomedSpace.x, y: localInUnZoomedSpace.y)
            .scaledBy(x: zoomFactor, y: zoomFactor)
            .translatedBy(x: -localInUnZoomedSpace.x, y: -localInUnZoomedSpace.y)

        // put the transform part in the translation
        translation += [newTransform.tx, newTransform.ty]

        // put the scale part in zoom
        zoom = sqrt(Double(newTransform.a * newTransform.a + newTransform.c * newTransform.c))

        setNeedsDisplay(self.bounds)
    }
}
