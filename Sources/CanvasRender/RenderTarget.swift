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
