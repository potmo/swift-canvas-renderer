import Cocoa
import Foundation
import Observation
import SwiftUI

public class ManualCanvasRenderer {
    private let transformer: any RenderTransformer
    private let maker: any ManualShapeMaker
    private var mousePos = Vector2D()

    public init(transformer: any RenderTransformer, maker: any ManualShapeMaker) {
        self.transformer = transformer
        self.maker = maker
    }

    public func setMousePos(_ pos: Vector2D) {
        self.mousePos = pos
    }

    func render(graphicsContext: inout GraphicsContext, frame: CGSize) {
        render(into: GraphicsContextRenderTarget(context: graphicsContext), frame: frame)
    }

    /// Draws the shapes into `renderTarget`, which uses the coordinates of a SwiftUI canvas of size `frame`
    /// (origin top left, y down). The projected 2D space is centered and y-up, so a top view shows world Y upwards.
    public func render(into renderTarget: RenderTarget, frame: CGSize) {
        let shapes = self.maker.shapes()

        let transform = CGAffineTransform(scaleX: 1, y: -1)
            .concatenating(CGAffineTransform(translationX: frame.width / 2, y: frame.height / 2))

        let context = RenderContext(canvasSize: Vector2D(frame.width, frame.height),
                                    renderTarget: renderTarget,
                                    transform2d: transform,
                                    transform3d: transformer)

        renderTarget.setStrokeColor(context.color.cgColor)
        renderTarget.setLineWidth(context.lineWidth)

        shapes.forEach { $0.draw(in: context) }

        // draw frame
        let border = 10.0
        renderTarget.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.5))
        renderTarget.beginPath(id: nil)
        renderTarget.move(to: CGPoint(x: border, y: border))
        renderTarget.addLine(to: CGPoint(x: frame.width - border, y: border))
        renderTarget.addLine(to: CGPoint(x: frame.width - border, y: frame.height - border))
        renderTarget.addLine(to: CGPoint(x: border, y: frame.height - border))
        renderTarget.closePath()
        renderTarget.strokePath()
    }
}

public struct ShapeCanvas: View {
    @State var renderer: ManualCanvasRenderer
    @State var camera: PerspectiveCamera
    @State var currentTime: CurrentTime

    @State var updateCallback: (_ frame: CGSize, _ time: Double) -> Void

    public init(renderer: ManualCanvasRenderer, camera: PerspectiveCamera, _ onTick: @escaping (_ frame: CGSize, _ time: Double) -> Void) {
        self.renderer = renderer
        self.camera = camera
        self.currentTime = CurrentTime()
        self.updateCallback = onTick
    }

    public var body: some View {
        SwiftUI.TimelineView(.animation) { context in
            SwiftUI.Canvas(opaque: true, colorMode: .linear) { graphicsContext, frame in
                currentTime.update(with: context.date)
                updateCallback(frame, currentTime.timeSinceStart)
                renderer.render(graphicsContext: &graphicsContext, frame: frame)
            }
        }
    }
}

@Observable
class CurrentTime {
    private let startTime: TimeInterval
    var timeSinceStart: TimeInterval

    init() {
        self.startTime = Date().timeIntervalSince1970
        self.timeSinceStart = 0
    }

    func update(with time: Date) {
        self.timeSinceStart = time.timeIntervalSince1970 - startTime
    }
}

public protocol ManualShapeMaker {
    @CanvasBuilder
    func shapes() -> [any DrawableShape]
}
