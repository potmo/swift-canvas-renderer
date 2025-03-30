import CoreGraphics
import CoreText
import Foundation
import SwiftUI

public protocol RenderTarget {
    func addLine(to point: CGPoint)
    func move(to point: CGPoint)
    func beginPath()
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

class GraphicsContextRenderTarget: RenderTarget {
    private let context: GraphicsContext

    private var currentPath: SwiftUI.Path?
    private var currentStrokeColor: Color = .black
    private var currentStrokeStyle = StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)

    init(context: GraphicsContext) {
        self.context = context
    }

    func beginPath() {
        self.currentPath = SwiftUI.Path()
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
        path.addLine(to: point)
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
        let startPos = CGPoint(x: center.x + cos(startAngle) * radius,
                               y: center.y + sin(startAngle) * radius)

        self.move(to: startPos)

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
        cgContext.addLine(to: point)
    }

    func move(to point: CGPoint) {
        cgContext.move(to: point)
    }

    func beginPath() {
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
        // swap the direction of rotation since the CGtransform has screwed things up it makes the cos/sin angle go counter clockwise
        // this makes it go clockwise
        // let delta = atan2(sin(endAngle - startAngle), cos(endAngle - startAngle))
        // let fixedEndAngle = startAngle - delta

        // mark start

        let startPos = CGPoint(x: center.x + cos(startAngle) * radius,
                               y: center.y + sin(startAngle) * radius)

        cgContext.move(to: startPos)

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

public class DXFLWLineRenderTarget: RenderTarget {
    static let snappingThreshold: CGFloat = 0.0001

    private var currentPosition: CGPoint? = nil
    public private(set) var openNodes: [NodePath] = []
    public private(set) var closedNodes: [NodePath] = []
    public private(set) var immutableOpenNodes: [NodePath] = []

    public init() {
    }

    public func dxf(pdfFileName: String?, dxfFileName: String?, includeHeader: Bool) -> String {
        let pdfOutput: String
        let header: String
        let dxfOutput: String

        let dxfClosedContent = closedNodes.map { node in
            let points = node.array.flatMap(\.content.polyLineString).joined(separator: ", ")
            return "msp.add_lwpolyline([\(points)], close=True)"
        }.joined(separator: "\n")

        let dxfOpenContent = (openNodes + immutableOpenNodes).map { node in
            let points = node.array.flatMap(\.content.polyLineString).joined(separator: ", ")
            return "msp.add_lwpolyline([\(points)], close=False)"
        }.joined(separator: "\n")

        let dxfContent = dxfClosedContent + "\n" + dxfOpenContent

        if includeHeader {
            header = """
            import ezdxf
            from ezdxf.addons.drawing import Frontend, RenderContext, pymupdf, layout, config
            from ezdxf.math import ConstructionArc
            from sys import stdout, stderr
            from ezdxf import units
            """
        } else {
            header = ""
        }

        if let dxfFileName {
            dxfOutput = """
            doc = ezdxf.new("AC1027", setup=True) # Autocad R2013
            doc.units = units.MM
            msp = doc.modelspace()
            \(DXFRenderTarget.DXFLayer.allCases.flatMap {
                [
                    "shapeLayer = doc.layers.add(\"\($0.string)\")",
                    "shapeLayer.color = ezdxf.colors.\($0.color)",
                    "shapeLayer.linetype = \"\($0.linetype)\"",
                    "shapeLayer.lineweight = \"\(20)\"", // lineweight is mm times 100 so 20 = 0.2mm
                ]
            }.joined(separator: "\n"))
            \(dxfContent)

            doc.validate()

            doc.saveas("\(dxfFileName)")

            """
        } else {
            dxfOutput = ""
        }

        if let pdfFileName {
            pdfOutput = """
            context = RenderContext(doc)
            backend = pymupdf.PyMuPdfBackend()
            cfg = config.Configuration(background_policy=config.BackgroundPolicy.WHITE)
            frontend = Frontend(context, backend, config=cfg)
            frontend.draw_layout(msp)
            page = layout.Page(3000, 1500, layout.Units.mm, margins=layout.Margins.all(20))
            pdf_bytes = backend.get_pdf_bytes(page)
            with open("\(pdfFileName)", "wb") as fp:
                fp.write(pdf_bytes)

            #doc.write(stdout) # this prints it all to stdout
            """
        } else {
            pdfOutput = ""
        }

        return """
        \(header)
        \(dxfOutput)
        \(pdfOutput)
        """
    }

    private func addOpen(_ nodeContent: NodeContent) {
        let node = Node(content: nodeContent)

        let nodePath = NodePath(node: node)
        openNodes.append(nodePath)
        tryJoinNodes(node: nodePath)
    }

    private func addClosed(_ nodeContent: NodeContent) {
        var node = Node(content: nodeContent)
        node.next = node

        let nodePath = NodePath(node: node)

        closedNodes.append(nodePath)
    }

    public func makeCurrentOpenNodesImmutable() {
        immutableOpenNodes.append(contentsOf: openNodes)
        openNodes = []
    }

    private func moveNodeIfClosed(node: NodePath) {
        if node.closed {
            openNodes.removeAll { $0 === node }
            closedNodes.append(node)
        }
    }

    private func tryJoinNodes(node: NodePath) {
        for openNode in openNodes where openNode !== node {
            if openNode.tail.content.endPoint.distance(to: node.head.content.startPoint) < Self.snappingThreshold {
                openNode.joinWith(headOf: node)
                openNodes.removeAll { $0 === node }

                if openNode.closed {
                    moveNodeIfClosed(node: openNode)
                } else {
                    tryJoinNodes(node: openNode)
                }
                return
            } else if openNode.head.content.startPoint.distance(to: node.tail.content.endPoint) < Self.snappingThreshold {
                openNode.joinWith(tailOf: node)
                openNodes.removeAll { $0 === node }
                if openNode.closed {
                    moveNodeIfClosed(node: openNode)
                } else {
                    tryJoinNodes(node: openNode)
                }
                return
            } else if openNode.head.content.startPoint.distance(to: node.head.content.startPoint) < Self.snappingThreshold {
                node.flip()
                openNode.joinWith(tailOf: node)
                openNodes.removeAll { $0 === node }
                if openNode.closed {
                    moveNodeIfClosed(node: openNode)
                } else {
                    tryJoinNodes(node: openNode)
                }
                return
            } else if openNode.tail.content.endPoint.distance(to: node.tail.content.endPoint) < Self.snappingThreshold {
                node.flip()
                openNode.joinWith(headOf: node)
                openNodes.removeAll { $0 === node }
                if openNode.closed {
                    moveNodeIfClosed(node: openNode)
                } else {
                    tryJoinNodes(node: openNode)
                }
                return
            }
        }
    }

    public func addLine(to point: CGPoint) {
        guard let currentPosition else {
            fatalError("can not end a line segment without a start")
        }

        let segment = LineSegment(startPoint: currentPosition, endPoint: point)
        self.currentPosition = point
        addOpen(segment)
    }

    public func move(to point: CGPoint) {
        self.currentPosition = point
    }

    public func beginPath() {
        // noop
    }

    public func strokePath() {
        // noop
    }

    public func fillPath() {
        // noop
    }

    public func closePath() {
        // TODO: Figure this out
    }

    public func setLineDash(phase: CGFloat, lengths: [CGFloat]) {
        // noop
    }

    public func setStrokeColor(_ color: CGColor) {
        // noop
    }

    public func setLineWidth(_ width: CGFloat) {
        // noop
    }

    public func text(_ string: String, position: CGPoint, size: CGFloat) {
        // noop
    }

    public func arc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, counterClockwise: Bool) {
        let startPoint = CGPoint(x: center.x + radius * cos(startAngle), y: center.y + radius * sin(startAngle))
        let endPoint = CGPoint(x: center.x + radius * cos(endAngle), y: center.y + radius * sin(endAngle))
        let arc = Arc(startAngle: startAngle,
                      endAngle: endAngle,
                      center: center,
                      radius: radius,
                      startPoint: startPoint,
                      endPoint: endPoint,
                      ccw: counterClockwise)

        self.currentPosition = endPoint
        addOpen(arc)
    }

    public func addComment(_ string: String) {
        // noop
    }

    public func circle(center: CGPoint, radius: CGFloat) {
        let counterClockwise = true

        var startAngle = 0.0
        var endAngle = 1.0 * .pi
        var startPoint = CGPoint(x: center.x + radius * cos(startAngle), y: center.y + radius * sin(startAngle))
        var endPoint = CGPoint(x: center.x + radius * cos(endAngle), y: center.y + radius * sin(endAngle))

        let arc0 = Arc(startAngle: startAngle,
                       endAngle: endAngle,
                       center: center,
                       radius: radius,
                       startPoint: startPoint,
                       endPoint: endPoint,
                       ccw: counterClockwise)

        startAngle = 1.0 * .pi
        endAngle = 0.0

        startPoint = CGPoint(x: center.x + radius * cos(startAngle), y: center.y + radius * sin(startAngle))
        endPoint = CGPoint(x: center.x + radius * cos(endAngle), y: center.y + radius * sin(endAngle))

        let arc1 = Arc(startAngle: startAngle,
                       endAngle: endAngle,
                       center: center,
                       radius: radius,
                       startPoint: startPoint,
                       endPoint: endPoint,
                       ccw: counterClockwise)

        self.currentPosition = endPoint

        // shortcut adding nodes and just add the two halfs to the closed nodes
        let node0 = Node(content: arc0)
        let node1 = Node(content: arc1)

        let nodePath = NodePath(node: node0)
        nodePath.joinWith(headOf: NodePath(node: node1))
        closedNodes.append(nodePath)
    }

    struct Arc: NodeContent {
        var startAngle: CGFloat
        var endAngle: CGFloat
        var originalStartAngle: CGFloat
        var originalEndAngle: CGFloat
        var center: CGPoint
        var radius: CGFloat
        var startPoint: CGPoint
        var endPoint: CGPoint
        var ccw: Bool

        init(startAngle: CGFloat, endAngle: CGFloat, center: CGPoint, radius: CGFloat, startPoint: CGPoint, endPoint: CGPoint, ccw: Bool) {
            self.startAngle = startAngle
            self.endAngle = endAngle
            self.originalStartAngle = startAngle
            self.originalEndAngle = endAngle
            self.center = center
            self.radius = radius
            self.startPoint = startPoint
            self.endPoint = endPoint
            self.ccw = ccw
        }

        mutating func flip() {
            // FIXME: ALso flip the other params
            swap(&startPoint, &endPoint)
            swap(&startAngle, &endAngle)
            ccw = !ccw
        }

        func draw(in context: RenderContext) {
            let radius = context.transform(center.vector2D.xyVector3D).distance(to: context.transform(startPoint.vector2D.xyVector3D))
            context.renderTarget.arc(center: context.transform(center.vector2D.xyVector3D),
                                     radius: radius,
                                     startAngle: startAngle,
                                     endAngle: endAngle,
                                     counterClockwise: ccw)
        }

        var polyLineString: [String] {
            return [
                """
                (\(startPoint.x.toFixed(5)), \(startPoint.y.toFixed(5)), 0, 0, \(ccw ? "" : "-") ezdxf.math.arc_to_bulge((\(center.x.toFixed(5)),\(center.y.toFixed(5))), \(originalStartAngle.toFixed(2)), \(originalEndAngle.toFixed(2)), \(radius.toFixed(5)))[-1]) 
                """,
                """
                (\(endPoint.x.toFixed(5)), \(endPoint.y.toFixed(5)))
                """,
            ]
        }
    }

    struct LineSegment: NodeContent {
        var startPoint: CGPoint
        var endPoint: CGPoint

        mutating func flip() {
            swap(&startPoint, &endPoint)
        }

        func draw(in context: RenderContext) {
            context.renderTarget.addLine(to: context.transform(endPoint.vector2D.xyVector3D))
        }

        var polyLineString: [String] {
            return [
                """
                (\(startPoint.x.toFixed(5)), \(startPoint.y.toFixed(5)))
                """,
                """
                (\(endPoint.x.toFixed(5)), \(endPoint.y.toFixed(5)))
                """,
            ]
        }
    }

    public protocol NodeContent {
        var startPoint: CGPoint { get }
        var endPoint: CGPoint { get }
        func draw(in context: RenderContext)
        var polyLineString: [String] { get }
        mutating func flip()
    }

    public class Node {
        public let id: UUID
        public var content: NodeContent
        public internal(set) var next: Node?
        init(content: NodeContent) {
            self.id = UUID()
            self.content = content
        }
    }

    public class NodePath: CustomDebugStringConvertible {
        public var head: Node
        public var tail: Node

        public var closed: Bool {
            self.head.id == self.tail.id && head.next != nil
        }

        init(node: Node) {
            self.head = node
            self.tail = node
        }

        public var debugDescription: String {
            return array.map(\.id).map(\.uuidString).joined(separator: "->")
        }

        public var array: [Node] {
            var output: [Node] = []
            var current = head
            while true {
                output.append(current)
                guard let next = current.next else {
                    break
                }
                guard next !== head else {
                    break
                }
                current = next
            }
            return output
        }

        func flip() {
            if head === tail {
                head.content.flip()
                return
            }
            var previous: Node? = nil
            var current = head
            while true {
                let next = current.next
                current.content.flip()
                current.next = previous
                previous = current
                guard let next else {
                    break
                }
                if next.id == head.id {
                    break
                }
                current = next
            }

            swap(&head, &tail)
        }

        func pushAtHead(_ node: Node) {
            node.next = self.head
            self.head = node

            closeIfPossible()
        }

        func pushAtTail(_ node: Node) {
            self.tail.next = node
            self.tail = node

            closeIfPossible()
        }

        func joinWith(headOf other: NodePath) {
            self.tail.next = other.head
            self.tail = other.tail
            closeIfPossible()
        }

        func joinWith(tailOf other: NodePath) {
            other.tail.next = self.head
            self.head = other.head
            closeIfPossible()
        }

        func closeIfPossible() {
            if tail.content.endPoint.distance(to: head.content.startPoint) <= DXFLWLineRenderTarget.snappingThreshold {
                self.tail.next = self.head
                self.tail = self.head
            }
        }
    }
}

public class DXFRenderTarget: RenderTarget {
    private var currentPath: [CGPoint] = []
    private var dxfContent = ""

    private var color = CanvasColor.black
    private var dash = false

    private var layer: DXFLayer {
        if dash {
            return .dash
        }

        if color == .yellow {
            return .etch
        }

        return .cut
    }

    enum DXFLayer: CaseIterable {
        case cut
        case etch
        case dash

        var string: String {
            switch self {
            case .cut: "cut"
            case .etch: "etch"
            case .dash: "dash"
            }
        }

        var color: String {
            switch self {
            case .cut: "BLACK"
            case .etch: "YELLOW"
            case .dash: "RED"
            }
        }

        var linetype: String {
            switch self {
            case .cut: "CONTINUOUS"
            case .etch: "CONTINUOUS"
            case .dash: "DASHED"
            }
        }
    }

    public init() {
    }

    public func addLine(to point: CGPoint) {
        currentPath.append(point)
    }

    public func move(to point: CGPoint) {
        // if this will break the line we need to print it
        if !currentPath.isEmpty {
            strokePath()
        }

        currentPath.append(point)
    }

    public func arc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, counterClockwise: Bool = true) {
        if !currentPath.isEmpty {
            strokePath()
        }

        let formattedCenter = center.formatted

        let point1 = CGPoint(x: center.x + cos(startAngle) * radius,
                             y: center.y + sin(startAngle) * radius).formatted

        let point2 = CGPoint(x: center.x + cos(endAngle) * radius,
                             y: center.y + sin(endAngle) * radius).formatted

        if point1 == point2 {
            return
        }

//        arc = ConstructionArc.from_3p(
//            start_point=(\(point1.x), \(point1.y)), end_point=(\(point2.x), \(point2.y)), def_point=(\(center.x), \(center.y))
//        )

        let formattedStartAngle = CGFloat(Double(startAngle).radiansToDegrees).formatted
        let formattedEndAngle = CGFloat(Double(endAngle).radiansToDegrees).formatted

        dxfContent += """

        arc = ConstructionArc(center=(\(center.x), \(center.y)), radius=\(radius.formatted), start_angle=\(formattedStartAngle), end_angle=\(formattedEndAngle), is_counter_clockwise=\(counterClockwise ? "True" : "False"))
        arc.add_to_layout(msp, dxfattribs={\"layer\": \"\(layer.string)\", \"linetype\": \"\(layer.linetype)\"})
        """
    }

    public func circle(center: CGPoint, radius: CGFloat) {
        dxfContent += """

        msp.add_circle(center=(\(center.x), \(center.y)), radius=\(radius.formatted), dxfattribs={\"layer\": \"\(layer.string)\", \"linetype\": \"\(layer.linetype)\"})
        """
    }

    public func addComment(_ string: String) {
        dxfContent += "\n#\(string)"
    }

    public func beginPath() {
        currentPath = []
    }

    public func strokePath() {
        // points = [(0, 0), (3, 0), (6, 3), (6, 6)]
        // msp.add_lwpolyline(points)

        let points = currentPath.map { point in
            let p = point.formatted
            return "(\(p.x), \(p.y))"
        }
        .joined(separator: ", ")

        dxfContent += "\nmsp.add_lwpolyline([\(points)], dxfattribs={\"layer\": \"\(layer.string)\", \"linetype\": \"\(layer.linetype)\"})"

        currentPath = []
    }

    public func fillPath() {
        // FIXME: Implement
        fatalError("not implemented")
    }

    public func closePath() {
        guard let firstPoint = currentPath.first else {
            return
        }
        currentPath.append(firstPoint)
    }

    public func setLineDash(phase: CGFloat, lengths: [CGFloat]) {
        // we don't define the dash here we just set it as the dash layer or not
        self.dash = !lengths.isEmpty
    }

    public func setStrokeColor(_ color: CGColor) {
        // we only define the yellow layer otherwise it is black
        if color == CanvasColor.yellow.cgColor {
            self.color = .yellow
        } else {
            self.color = .black
        }
    }

    public func setLineWidth(_ width: CGFloat) {
        // TODO: Do this
    }

    public func text(_ string: String, position: CGPoint, size: CGFloat) {
    }

    public func dxf(pdfFileName: String?, dxfFileName: String?, includeHeader: Bool) -> String {
        let pdfOutput: String
        let header: String
        let dxfOutput: String

        if includeHeader {
            header = """
            import ezdxf
            from ezdxf.addons.drawing import Frontend, RenderContext, pymupdf, layout, config
            from ezdxf.math import ConstructionArc
            from sys import stdout, stderr
            from ezdxf import units
            """
        } else {
            header = ""
        }

        if let dxfFileName {
            dxfOutput = """
            doc = ezdxf.new("AC1027", setup=True) # Autocad R2013
            doc.units = units.MM
            msp = doc.modelspace()
            \(DXFLayer.allCases.flatMap {
                [
                    "shapeLayer = doc.layers.add(\"\($0.string)\")",
                    "shapeLayer.color = ezdxf.colors.\($0.color)",
                    "shapeLayer.linetype = \"\($0.linetype)\"",
                    "shapeLayer.lineweight = \"\(20)\"", // lineweight is mm times 100 so 20 = 0.2mm
                ]
            }.joined(separator: "\n"))
            \(dxfContent)

            doc.validate()

            doc.saveas("\(dxfFileName)")

            """
        } else {
            dxfOutput = ""
        }

        if let pdfFileName {
            pdfOutput = """
            context = RenderContext(doc)
            backend = pymupdf.PyMuPdfBackend()
            cfg = config.Configuration(background_policy=config.BackgroundPolicy.WHITE)
            frontend = Frontend(context, backend, config=cfg)
            frontend.draw_layout(msp)
            page = layout.Page(3000, 1500, layout.Units.mm, margins=layout.Margins.all(20))
            pdf_bytes = backend.get_pdf_bytes(page)
            with open("\(pdfFileName)", "wb") as fp:
                fp.write(pdf_bytes)

            #doc.write(stdout) # this prints it all to stdout
            """
        } else {
            pdfOutput = ""
        }

        return """
        \(header)
        \(dxfOutput)
        \(pdfOutput)
        """
    }
}

public class SVGRenderTarget: RenderTarget {
    private var currentPath: [SVGCommand]?
    private var svgContent = ""
    private var currentColor = "#000000"
    private var currentStrokeDash: String?
    private var currentStrokeWidth = "1"

    private let width = 1000.0
    private let height = 1000.0

    public init() {
        self.currentPath = nil
    }

    public func closePath() {
        guard currentPath != nil else {
            fatalError("no current path")
        }

        currentPath?.append(.closePath)
    }

    public func arc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, counterClockwise: Bool = true) {
        // https://www.nan.fyi/svg-paths/arcs
        // TODO: Fix this
    }

    public func circle(center: CGPoint, radius: CGFloat) {
        // TODO: fix this
    }

    public func move(to point: CGPoint) {
        currentPath?.append(.move(x: point.x, y: -point.y))
    }

    public func addLine(to point: CGPoint) {
        currentPath?.append(.line(x: point.x, y: -point.y))
    }

    public func beginPath() {
        currentPath = []
    }

    public func setLineDash(phase: CGFloat, lengths: [CGFloat]) {
        if lengths.isEmpty {
            currentStrokeDash = nil
        } else {
            currentStrokeDash = lengths.map(Int.init).map(\.description).joined(separator: ",")
        }
    }

    public func setLineWidth(_ width: CGFloat) {
        currentStrokeWidth = "\(Int(width))"
    }

    public func setStrokeColor(_ color: CGColor) {
        guard let components = color.components else {
            fatalError("smack")
        }
        let red = Float(components[0])
        let green = Float(components[1])
        let blue = Float(components[2])
        self.currentColor = String(format: "#%02lX%02lX%02lX", lroundf(red * 255), lroundf(green * 255), lroundf(blue * 255))
    }

    public func strokePath() {
        guard let currentPath else {
            return
        }

        let content = currentPath.map(\.string).joined(separator: " ")

        let color = "stroke=\"\(currentColor)\""
        let dash: String
        if let currentStrokeDash {
            dash = "stroke-dasharray=\"\(currentStrokeDash)\""
        } else {
            dash = ""
        }
        let strokeWidth = "stroke-width=\"\(currentStrokeWidth)\""
        svgContent += "<path d=\"\(content)\" \(color) \(dash) fill=\"none\" />\n"
    }

    public func fillPath() {
        // FIXME: Implement
        fatalError("not implemented")
    }

    public func text(_ string: String, position: CGPoint, size: CGFloat) {
        svgContent += "<text x=\"\(position.x)\" y=\"\(position.y)\" font-size=\"\(size)\">\(string)</text>\n"
    }

    public func addComment(_ string: String) {
        svgContent += "\n//\(string)"
    }

    public var svg: String {
        return
            """
            <svg width="\(width)" height="\(height)">
            \(svgContent)
            </svg>
            """
    }

    enum SVGCommand {
        static var numberFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.usesGroupingSeparator = false
            formatter.decimalSeparator = "."
            formatter.alwaysShowsDecimalSeparator = true
            formatter.hasThousandSeparators = false
            formatter.maximumFractionDigits = 8
            formatter.minimumFractionDigits = 1
            return formatter
        }

        case move(x: Double, y: Double)
        case line(x: Double, y: Double)
        case closePath

        var string: String {
            switch self {
            case let .move(x, y):
                return "M\(Self.numberFormatter.string(from: x as! NSNumber)!) \(Self.numberFormatter.string(from: y as! NSNumber)!)"
            case let .line(x, y):
                return "L\(Self.numberFormatter.string(from: x as! NSNumber)!) \(Self.numberFormatter.string(from: y as! NSNumber)!)"
            case .closePath:
                return "Z"
            }
        }
    }
}
