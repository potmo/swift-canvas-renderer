import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct PathNumber: DrawableShape {
    let paths: [Path]

    public init(number: Int, topCorner: Vector, sideDirection: Vector, downDirection: Vector, scale: Double) {
        let digits: [Int] = "\(number)"
            .compactMap(\.wholeNumberValue)

        self.paths = digits.enumerated().map { index, digit in

            let localTopCorner = topCorner + sideDirection.scaled(by: scale * Double(index))

            switch digit {
            case 0: return Self.zero(localTopCorner, sideDirection, downDirection, scale)
            case 1: return Self.one(localTopCorner, sideDirection, downDirection, scale)
            case 2: return Self.two(localTopCorner, sideDirection, downDirection, scale)
            case 3: return Self.three(localTopCorner, sideDirection, downDirection, scale)
            case 4: return Self.four(localTopCorner, sideDirection, downDirection, scale)
            case 5: return Self.five(localTopCorner, sideDirection, downDirection, scale)
            case 6: return Self.six(localTopCorner, sideDirection, downDirection, scale)
            case 7: return Self.seven(localTopCorner, sideDirection, downDirection, scale)
            case 8: return Self.eight(localTopCorner, sideDirection, downDirection, scale)
            case 9: return Self.nine(localTopCorner, sideDirection, downDirection, scale)
            default: return Self.space(localTopCorner, sideDirection, downDirection, scale)
            }
        }
    }

    public func draw(in context: RenderContext) {
        for path in paths {
            path.draw(in: context)
        }
    }

    private static func space(_ topCorner: Vector, _ right: Vector, _ down: Vector, _ scale: Double) -> Path {
        return Path(closed: false) {
        }
    }

    private static func zero(_ topCorner: Vector, _ right: Vector, _ down: Vector, _ scale: Double) -> Path {
        let topCenter = topCorner + right.scaled(by: scale).scaled(by: 0.5) + down.scaled(by: scale).scaled(by: 0.25)
        let bottomCenter = topCorner + right.scaled(by: scale).scaled(by: 0.5) + down.scaled(by: scale).scaled(by: 0.75)
        let topRadius = scale * 0.25
        let bottomRadius = scale * 0.25
        let axis = right.cross(down)
        return Path(closed: false) {
            Comment("zero")
            AxisOrbit(pivot: topCenter,
                      point: topCenter + right.scaled(by: -topRadius),
                      angle: .pi,
                      axis: axis)

            LineTo(bottomCenter + right.scaled(by: bottomRadius))

            AxisOrbit(pivot: bottomCenter,
                      point: bottomCenter + right.scaled(by: bottomRadius),
                      angle: .pi,
                      axis: axis)

            LineTo(topCenter + right.scaled(by: -topRadius))
        }
    }

    private static func one(_ topCorner: Vector, _ right: Vector, _ down: Vector, _ scale: Double) -> Path {
        let axis = right.cross(down)
        let topCenter = topCorner + right.scaled(by: scale).scaled(by: 0.53)
        let bottomCenter = topCorner + right.scaled(by: scale).scaled(by: 0.47) + down.scaled(by: scale)
        let nubbin = topCenter + Quat(angle: .pi - .pi * 0.3, axis: axis).act(right.scaled(by: scale * 0.2))
        return Path(closed: false) {
            Comment("one")
            MoveTo(nubbin)
            LineTo(topCenter)
            LineTo(bottomCenter)
        }
    }

    private static func two(_ topCorner: Vector, _ right: Vector, _ down: Vector, _ scale: Double) -> Path {
        let axis = right.cross(down)
        let topCenter = topCorner + right.scaled(by: scale * 0.5) + down.scaled(by: scale * 0.25)
        let bottomCenter = topCorner + right.scaled(by: scale * 0.5) + down.scaled(by: scale)
        return Path(closed: false) {
            Comment("two")
            AxisOrbit(pivot: topCenter,
                      point: topCenter + right.scaled(by: -scale * 0.25),
                      angle: .pi * 1.2,
                      axis: axis)
            LineTo(bottomCenter + right.scaled(by: -scale * 0.25))
            LineTo(bottomCenter + right.scaled(by: scale * 0.25))
        }
    }

    private static func three(_ topCorner: Vector, _ right: Vector, _ down: Vector, _ scale: Double) -> Path {
        let axis = right.cross(down)
        let topCenter = topCorner + right.scaled(by: scale * 0.5)
        let bottomCenter = topCorner + right.scaled(by: scale * 0.5) + down.scaled(by: scale)
        let rotationCenter = bottomCenter + down.scaled(by: -scale * 0.25)
        let startCurve = rotationCenter + Quat(angle: -.pi * 0.6, axis: axis).act(right.scaled(by: scale * 0.25))
        return Path(closed: false) {
            Comment("three")
            MoveTo(topCenter + right.scaled(by: -scale * 0.25))
            LineTo(topCenter + right.scaled(by: scale * 0.25))
            LineTo(startCurve)
            AxisOrbit(pivot: rotationCenter,
                      point: startCurve,
                      angle: .pi * 1.5,
                      axis: axis)
        }
    }

    private static func four(_ topCorner: Vector, _ right: Vector, _ down: Vector, _ scale: Double) -> Path {
        let axis = right.cross(down)
        let topCenter = topCorner + right.scaled(by: scale * 0.5)
        let bottomCenter = topCorner + right.scaled(by: scale * 0.5) + down.scaled(by: scale)

        return Path(closed: false) {
            Comment("four")
            MoveTo(topCenter + right.scaled(by: -scale * 0.15))
            LineTo(topCenter + right.scaled(by: -scale * 0.25) + down.scaled(by: scale * 0.5))
            LineTo(topCenter + right.scaled(by: scale * 0.25) + down.scaled(by: scale * 0.5))
            MoveTo(topCenter + right.scaled(by: scale * 0.25))
            LineTo(topCenter + right.scaled(by: scale * 0.15) + down.scaled(by: scale))
        }
    }

    private static func five(_ topCorner: Vector, _ right: Vector, _ down: Vector, _ scale: Double) -> Path {
        let axis = right.cross(down)
        let topCenter = topCorner + right.scaled(by: scale * 0.5)
        let bottomCenter = topCorner + right.scaled(by: scale * 0.5) + down.scaled(by: scale)
        let rotationCenter = bottomCenter + down.scaled(by: -scale * 0.25)
        let startCurve = rotationCenter + Quat(angle: -.pi * 0.7, axis: axis).act(right.scaled(by: scale * 0.25))
        return Path(closed: false) {
            Comment("five")
            MoveTo(topCenter + right.scaled(by: scale * 0.25))
            LineTo(topCenter + right.scaled(by: -scale * 0.05))
            LineTo(startCurve)
            AxisOrbit(pivot: rotationCenter,
                      point: startCurve,
                      angle: .pi * 1.5,
                      axis: axis)
        }
    }

    private static func six(_ topCorner: Vector, _ right: Vector, _ down: Vector, _ scale: Double) -> Path {
        let axis = right.cross(down)
        let topCenter = topCorner + right.scaled(by: scale * 0.5)
        let bottomCenter = topCorner + right.scaled(by: scale * 0.5) + down.scaled(by: scale)
        let rotationCenter = bottomCenter + down.scaled(by: -scale * 0.25)
        let startCurve = rotationCenter + Quat(angle: -.pi * 0.9, axis: axis).act(right.scaled(by: scale * 0.25))

        return Path(closed: false) {
            Comment("six")
            MoveTo(topCenter + right.scaled(by: -scale * 0.05))
            LineTo(startCurve)
            AxisOrbit(pivot: rotationCenter,
                      point: startCurve,
                      angle: .pi * 2,
                      axis: axis)
        }
    }

    private static func seven(_ topCorner: Vector, _ right: Vector, _ down: Vector, _ scale: Double) -> Path {
        let topCenter = topCorner + right.scaled(by: scale * 0.5)
        let bottomCenter = topCorner + right.scaled(by: scale * 0.5) + down.scaled(by: scale)

        return Path(closed: false) {
            Comment("seven")
            MoveTo(topCenter + right.scaled(by: -scale * 0.25))
            LineTo(topCenter + right.scaled(by: scale * 0.25))
            LineTo(bottomCenter + right.scaled(by: -scale * 0.1))
        }
    }

    private static func eight(_ topCorner: Vector, _ right: Vector, _ down: Vector, _ scale: Double) -> Path {
        let topCenter = topCorner + right.scaled(by: scale * 0.5)
        let bottomCenter = topCorner + right.scaled(by: scale * 0.5) + down.scaled(by: scale)
        let topRotationCenter = topCenter + down.scaled(by: scale * 0.25)
        let bottomRotationCenter = bottomCenter + down.scaled(by: -scale * 0.25)
        let axis = right.cross(down)
        return Path(closed: false) {
            Comment("eight")
            AxisOrbit(pivot: topRotationCenter,
                      point: topRotationCenter + down.scaled(by: scale * 0.25),
                      angle: .pi * 2,
                      axis: axis)
            AxisOrbit(pivot: bottomRotationCenter,
                      point: bottomRotationCenter + down.scaled(by: -scale * 0.25),
                      angle: .pi * 2,
                      axis: axis)
        }
    }

    private static func nine(_ topCorner: Vector, _ right: Vector, _ down: Vector, _ scale: Double) -> Path {
        let axis = right.cross(down)
        let topCenter = topCorner + right.scaled(by: scale * 0.5)
        let bottomCenter = topCorner + right.scaled(by: scale * 0.5) + down.scaled(by: scale)
        let rotationCenter = topCenter + down.scaled(by: scale * 0.25)
        let startCurve = rotationCenter + Quat(angle: .pi * 0.1, axis: axis).act(right.scaled(by: scale * 0.25))

        return Path(closed: false) {
            Comment("nine")
            MoveTo(bottomCenter + right.scaled(by: scale * 0.05))
            LineTo(startCurve)
            AxisOrbit(pivot: rotationCenter,
                      point: startCurve,
                      angle: .pi * 2,
                      axis: axis)
        }
    }
}
