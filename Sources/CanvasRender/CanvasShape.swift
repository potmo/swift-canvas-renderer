
import CoreGraphics
import Foundation
import simd
import SwiftUI

public protocol DrawableShape {
    func draw(in context: CGContext, using transform: CGAffineTransform)
}

public protocol DrawableObject: DrawableShape {
    @CanvasBuilder var shapes: [any DrawableShape] { get }
}

public extension DrawableObject {
    func draw(in context: CGContext, using transform: CGAffineTransform) {
        for shape in self.shapes {
            shape.draw(in: context, using: transform)
        }
    }
}

public protocol PartOfPath {
    func drawPartOfPath(in context: CGContext, using transform: CGAffineTransform)
}

public struct Path: DrawableShape {
    private let parts: [any PartOfPath]
    private let closed: Bool

    public init(closed: Bool = false, @PathBuilder _ builder: () -> [any PartOfPath]) {
        self.parts = builder()
        self.closed = closed
    }

    public init(closed: Bool = false, points: [Vector2D]) {
        self.init(closed: closed) {
            if let startPoint = points.first {
                MoveTo(startPoint)

                for point in points.dropFirst() {
                    LineTo(point)
                }
            }
        }
    }

    public func draw(in context: CGContext, using transform: CGAffineTransform) {
        context.beginPath()
        for part in parts {
            part.drawPartOfPath(in: context, using: transform)
        }
        if closed {
            context.closePath()
        }
        context.strokePath()
    }
}

public struct Circle: DrawableShape {
    let center: simd_double2
    let radius: simd_double1

    public init(center: simd_double2, radius: simd_double1) {
        self.center = center
        self.radius = radius
    }

    public init(center: simd_double3, radius: simd_double1, plane: AxisPlane) {
        self.center = center.inPlane(plane)
        self.radius = radius
    }

    public func draw(in context: CGContext, using transform: CGAffineTransform) {
        let center = CGPoint(x: center.x, y: center.y).applying(transform)

        // compute the x-scaling bit of the transform
        let transformedRadius = radius * sqrt(Double(transform.a * transform.a + transform.c * transform.c))

        context.beginPath()
        context.addArc(center: center,
                       radius: transformedRadius,
                       startAngle: 0,
                       endAngle: .pi * 2,
                       clockwise: true)
        context.closePath()
        context.strokePath()
    }
}

public struct Orbit: DrawableShape, PartOfPath {
    let pivot: simd_double3
    let point: simd_double3
    let rotation: simd_quatd
    let renderPlane: AxisPlane

    public init(pivot: simd_double3, point: simd_double3, rotation: simd_quatd, renderPlane: AxisPlane) {
        self.pivot = pivot
        self.point = point
        self.rotation = rotation
        self.renderPlane = renderPlane
    }

    public func draw(in context: CGContext, using transform: CGAffineTransform) {
        context.beginPath()
        drawPartOfPath(in: context, using: transform)
        context.strokePath()
    }

    public func drawPartOfPath(in context: CGContext, using transform: CGAffineTransform) {
        let lever = point - pivot

        context.move(to: point.inPlane(renderPlane).cgPoint.applying(transform))

        for t in stride(from: 0.0, through: 1.0, by: 0.1) {
            let rot = simd_slerp(.identity, rotation, t)
            let drawPoint = (pivot + rot.act(lever)).inPlane(renderPlane).cgPoint.applying(transform)
            context.addLine(to: drawPoint)
        }
    }
}

public struct Arc: DrawableShape, PartOfPath {
    let center: simd_double2
    let radius: simd_double1
    let startAngle: simd_double1
    let endAngle: simd_double1
    let clockwise: Bool

    public init(center: simd_double2, radius: simd_double1, startAngle: simd_double1, endAngle: simd_double1, clockwise: Bool = true) {
        self.center = center
        self.radius = radius
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.clockwise = true
    }

    public init(center: simd_double3, radius: simd_double1, startAngle: simd_double1, endAngle: simd_double1, clockwise: Bool = true, plane: AxisPlane) {
        self.center = center.inPlane(plane)
        self.radius = radius
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.clockwise = true
    }

    public func draw(in context: CGContext, using transform: CGAffineTransform) {
        context.beginPath()

        drawPartOfPath(in: context, using: transform)
        context.strokePath()
    }

    public func drawPartOfPath(in context: CGContext, using transform: CGAffineTransform) {
        let center = CGPoint(x: center.x, y: center.y).applying(transform)
        // compute the x-scaling bit of the transform
        let transformedRadius = radius * sqrt(Double(transform.a * transform.a + transform.c * transform.c))

        context.addArc(center: center,
                       radius: transformedRadius,
                       startAngle: startAngle,
                       endAngle: endAngle,
                       clockwise: !clockwise)
    }
}

public struct LineSection: DrawableShape, PartOfPath {
    let from: simd_double2
    let to: simd_double2

    public init(from: simd_double3, to: simd_double3, plane: AxisPlane) {
        self.from = plane.convert(from)
        self.to = plane.convert(to)
    }

    public init(from: simd_double2, to: simd_double2) {
        self.from = from
        self.to = to
    }

    public func drawPartOfPath(in context: CGContext, using transform: CGAffineTransform) {
        let a = CGPoint(x: from.x, y: from.y).applying(transform)
        let b = CGPoint(x: to.x, y: to.y).applying(transform)
        context.move(to: a)
        context.addLine(to: b)
    }

    public func draw(in context: CGContext, using transform: CGAffineTransform) {
        context.beginPath()
        drawPartOfPath(in: context, using: transform)
        context.strokePath()
    }
}

public struct Point: DrawableShape {
    let point: simd_double2

    public init(_ point: simd_double3, plane: AxisPlane) {
        self.point = plane.convert(point)
    }

    public init(_ point: simd_double2) {
        self.point = point
    }

    public func draw(in context: CGContext, using transform: CGAffineTransform) {
        let pos = point.cgPoint.applying(transform)

        context.beginPath()
        context.addArc(center: pos,
                       radius: 2,
                       startAngle: 0,
                       endAngle: .pi * 2,
                       clockwise: true)
        context.strokePath()
    }
}

public struct Arrow: DrawableShape {
    private let vector: simd_double2
    private let origo: simd_double2
    private let magnitude: Double

    public init(vector: simd_double3, origo: simd_double3 = [0, 0, 0], plane: AxisPlane) {
        self.init(vector: plane.convert(vector), origo: plane.convert(origo), magnitude: vector.length)
    }

    public init(vector: simd_double2, origo: simd_double2 = [0, 0]) {
        self.init(vector: vector, origo: origo, magnitude: vector.length)
    }

    private init(vector: simd_double2, origo: simd_double2, magnitude: Double) {
        self.vector = vector
        self.origo = origo
        self.magnitude = magnitude
    }

    public func draw(in context: CGContext, using transform: CGAffineTransform) {
        let vector = Vector(x: self.vector.x, y: self.vector.y, z: 0)

        let wingLengths = magnitude.scaled(by: 0.15)

        let arrowLeftSide = vector.normalized.scaled(by: wingLengths).rotated(by: Quat(angle: 170.degreesToRadians, axis: Vector(0, 0, 1)))
        let arrowRightSide = vector.normalized.scaled(by: wingLengths).rotated(by: Quat(angle: -170.degreesToRadians, axis: Vector(0, 0, 1)))

        Path {
            MoveTo(origo)
            LineTo(origo + vector.xy)
            LineTo(origo + (vector + arrowRightSide).xy)
            MoveTo(origo + vector.xy)
            LineTo(origo + (vector + arrowLeftSide).xy)
        }.draw(in: context, using: transform)
    }
}

public struct Dot: DrawableShape {
    let at: simd_double2

    public init(at: simd_double2) {
        self.at = at
    }

    public func draw(in context: CGContext, using transform: CGAffineTransform) {
        let pos = CGPoint(x: at.x, y: at.y).applying(transform)
        // compute the x-scaling bit of the transform
        // let radius = 5 * sqrt(transform.a * transform.a + transform.c * transform.c)

        context.beginPath()
        context.addArc(center: pos,
                       radius: 2,
                       startAngle: 0,
                       endAngle: .pi * 2,
                       clockwise: true)
        context.strokePath()
    }
}

public struct LineTo: PartOfPath {
    let point: simd_double2

    public init(_ point: simd_double2) {
        self.point = point
    }

    public init(_ point: simd_double3, plane: AxisPlane) {
        self.point = point.inPlane(plane)
    }

    public func drawPartOfPath(in context: CGContext, using transform: CGAffineTransform) {
        let a = CGPoint(x: point.x, y: point.y).applying(transform)
        context.addLine(to: a)
    }
}

public struct MoveTo: PartOfPath {
    let point: simd_double2

    public init(_ point: simd_double2) {
        self.point = point
    }

    public init(_ point: simd_double3, plane: AxisPlane) {
        self.point = point.inPlane(plane)
    }

    public func drawPartOfPath(in context: CGContext, using transform: CGAffineTransform) {
        let a = CGPoint(x: point.x, y: point.y).applying(transform)
        context.move(to: a)
    }
}

public struct Decoration: DrawableShape {
    let color: Color?
    let lineStyle: LineStyle?
    let lineWidth: Double?
    let shapes: [DrawableShape]

    public init(color: Color? = nil, lineStyle: LineStyle? = nil, lineWidth: Double? = nil, @CanvasBuilder _ builder: () -> [DrawableShape]) {
        self.color = color
        self.lineStyle = lineStyle
        self.shapes = builder()
        self.lineWidth = lineWidth
    }

    public func draw(in context: CGContext, using transform: CGAffineTransform) {
        context.saveGState()

        if let lineStyle {
            switch lineStyle {
            case .solid:
                context.setLineDash(phase: 0, lengths: [])
            case let .dashed(phase, lengths):
                context.setLineDash(phase: CGFloat(phase), lengths: lengths.map { CGFloat($0) })
            }
        }

        if let color {
            context.setStrokeColor(NSColor(color).cgColor)
        }

        if let lineWidth {
            context.setLineWidth(CGFloat(lineWidth))
        }

        for shape in shapes {
            shape.draw(in: context, using: transform)
        }
        context.restoreGState()
    }

    public enum LineStyle {
        case solid
        case dashed(phase: Double = 2, lengths: [Double] = [2, 2])
    }
}

public extension CGContext {
    func move(to point: simd_double2, transform: CGAffineTransform) {
        self.move(to: point.cgPoint.applying(transform))
    }

    func addLine(to point: simd_double2, transform: CGAffineTransform) {
        self.addLine(to: point.cgPoint.applying(transform))
    }
}
