import CoreGraphics
import CoreText
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
    func text(_ string: String, position: CGPoint, size: CGFloat)
    func arc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, counterClockwise: Bool)
    func addComment(_ string: String)
    func circle(center: CGPoint, radius: CGFloat)
}

extension CGContext: RenderTarget {
    public func arc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, counterClockwise: Bool = true) {
        // swap the direction of rotation since the CGtransform has screwed things up it makes the cos/sin angle go counter clockwise
        // this makes it go clockwise
        // let delta = atan2(sin(endAngle - startAngle), cos(endAngle - startAngle))
        // let fixedEndAngle = startAngle - delta

        // mark start

        let startPos = CGPoint(x: center.x + cos(startAngle) * radius,
                               y: center.y + sin(startAngle) * radius)

        self.move(to: startPos)

        self.addArc(center: center,
                    radius: radius,
                    startAngle: startAngle,
                    endAngle: endAngle,
                    clockwise: !counterClockwise)
    }

    public func circle(center: CGPoint, radius: CGFloat) {
        let startPos = CGPoint(x: center.x + radius,
                               y: center.y)

        self.addEllipse(in: CGRect(x: center.x - radius,
                                   y: center.y - radius,
                                   width: radius * 2,
                                   height: radius * 2))

        self.move(to: startPos)
    }

    public func text(_ string: String, position: CGPoint, size: CGFloat) {
        let context = self
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

        arc = ConstructionArc(center=(\(center.x), \(center.y)), radius=\(radius.formatted), start_angle=\(formattedStartAngle), end_angle=\(formattedEndAngle), is_counter_clockwise=\(counterClockwise ? "True": "False"))
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

    public var dxf: String {
        return """
        import ezdxf
        from ezdxf.addons.drawing import Frontend, RenderContext, pymupdf, layout, config
        from ezdxf.math import ConstructionArc
        from sys import stdout, stderr
        from ezdxf import units

        doc = ezdxf.new("AC1027", setup=True) # Autocad R2013
        doc.units = units.MM
        msp = doc.modelspace()
        \(DXFLayer.allCases.flatMap {
            [
                "shapeLayer = doc.layers.add(\"\($0.string)\")",
                "shapeLayer.color = ezdxf.colors.\($0.color)",
                "shapeLayer.linetype = \"\($0.linetype)\"",
            ]
        }.joined(separator: "\n"))
        \(dxfContent)


        doc.validate()

        doc.saveas("test-generated.dxf")


        context = RenderContext(doc)
        backend = pymupdf.PyMuPdfBackend()
        cfg = config.Configuration(background_policy=config.BackgroundPolicy.WHITE)
        frontend = Frontend(context, backend, config=cfg)
        frontend.draw_layout(msp)
        page = layout.Page(210, 297, layout.Units.mm, margins=layout.Margins.all(20))
        pdf_bytes = backend.get_pdf_bytes(page)
        with open("test-generated.pdf", "wb") as fp:
            fp.write(pdf_bytes)

        #doc.write(stdout) # this prints it all to stdout

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
