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
    @AppStorage("zoom") private var zoom = 1.0

    // workaround to make AppStorage store the translation (it cannot store complex types)
    @AppStorage("translationX") private var translationX: Double = 0
    @AppStorage("translationY") private var translationY: Double = 0
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

    init(state: StateType,
         maker: any ShapeMaker<StateType>) {
        self.maker = maker
        self.state = state
        super.init(frame: .zero)
        self.wantsRestingTouches = false
        self.allowedTouchTypes = .indirect
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

        guard let context = NSGraphicsContext.current?.cgContext else {
            fatalError("not able to create context for drawing")
        }

        // flip y-axis so origin is in top left corner
        context.concatenate(flipVerticalTransform)

        let transform = zoomTransform.concatenating(translateTransform)

        context.setStrokeColor(.black)
        context.setLineWidth(1.0)

        shapes.forEach { $0.draw(in: context, using: transform) }

        // draw shapes in input space
        // context.setStrokeColor(CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        // scence.forEach { $0.draw(in: context, using: .identity) }

        if let mousePos = mousePos {
            // draw mouse in screen space
            context.setLineDash(phase: 0, lengths: [])
            context.beginPath()
            context.setStrokeColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
            context.addArc(center: mousePos, radius: 5, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)
            context.strokePath()

            /*
              // draw mouse in input space
              let mappedMouse = mousePos.applying(transform.inverted())
             context.beginPath()
             context.setStrokeColor(CGColor(red: 0, green: 255, blue: 0, alpha: 1))
             context.addArc(center: mappedMouse, radius: 3, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)
             context.strokePath()
              */
        }
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

        // self.translateTransform = translateTransform.translatedBy(x: -delta.x * 2, y: delta.y * 2)

        setNeedsDisplay(self.bounds)
    }

    override func mouseDown(with event: NSEvent) {
        let local = self.convert(event.locationInWindow, to: self).applying(flipVerticalTransform)
        self.mousePos = local

        // if let mousePos = mousePos {
        // let transform = zoomTransform.concatenating(translateTransform)
        // let mappedMouse = mousePos.applying(transform.inverted())
        // }

        setNeedsDisplay(self.bounds)
    }

    override func mouseUp(with event: NSEvent) {
        //        let local = self.convert(event.locationInWindow, to: self)
        //        print("mouse up \(local.x) \(local.y)")
    }

    override func magnify(with event: NSEvent) {
        let local = self.convert(event.locationInWindow, to: self).applying(flipVerticalTransform)
        let localInUnZoomedSpace = local.applying(zoomTransform.concatenating(translateTransform).inverted())

        let zoomFactor = 1 / (1 - event.magnification)

        self.zoom = zoom * zoomFactor

        /*
         let zoomTransform = zoomTransform
             .translatedBy(x: localInUnZoomedSpace.x, y: localInUnZoomedSpace.y)
             .scaledBy(x: zoomFactor, y: zoomFactor)
             .translatedBy(x: -localInUnZoomedSpace.x, y: -localInUnZoomedSpace.y)
          */

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
        //
        //        translate.x += event.deltaX
        //        translate.y += event.deltaY
        //
        //        self.translateTransform = CGAffineTransform(translationX: translate.x, y: translate.y)
        //
        //        let local = self.convert(event.locationInWindow, to: self).applying(flipVerticalTransform)
        //        mousePos = local
        //
        //        setNeedsDisplay(self.bounds)
    }
}
