import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct StrokeNumber: DrawableShape {
    let polygons: [Polygon]

    public init(number: Int, topCorner: Vector, sideDirection: Vector, downDirection: Vector, scale: Double) {
        let digits: [Int] = "\(number)"
            .compactMap(\.wholeNumberValue)

        let coordinates: [[SIMD2<Double>]] = digits.compactMap { digit in
            switch digit {
            case 0: return Self.zero
            case 1: return Self.one
            case 2: return Self.two
            case 3: return Self.three
            case 4: return Self.four
            case 5: return Self.five
            case 6: return Self.six
            case 7: return Self.seven
            case 8: return Self.eight
                case 9: return Self.nine
            default: return Self.space
            }
        }

        let vertices: [[SIMD3<Double>]] = coordinates.enumerated()
            .map { (Double($0), $1) }
            .map { index, coordinates in
                return coordinates.map { coordinate in
                    return topCorner + (sideDirection.scaled(by: index) + sideDirection.scaled(by: coordinate.x * 0.7) + downDirection.scaled(by: coordinate.y)).scaled(by: scale)
                }
            }

        self.polygons = vertices.map { vertices in
            Polygon(vertices: vertices, closed: false)
        }
    }

    public func draw(in context: RenderContext) {
        for polygon in polygons {
            polygon.draw(in: context)
        }
    }

    private static let space: [SIMD2<Double>] = [
    ]

    private static let zero: [SIMD2<Double>] = [
        [0.0, 0.0],
        [1.0, 0.0],
        [1.0, 1.0],
        [0.0, 1.0],
        [0.0, 0.0],
    ]

    private static let one: [SIMD2<Double>] = [
        [0.5, 0.0],
        [0.5, 1.0],
    ]

    private static let two: [SIMD2<Double>] = [
        [0.0, 0.0],
        [1.0, 0.0],
        [1.0, 0.3],
        [0.0, 0.6],
        [0.0, 1.0],
        [1.0, 1.0],
    ]

    private static let three: [SIMD2<Double>] = [
        [0.0, 0.0],
        [1.0, 0.0],
        [0.6, 0.6],
        [1.0, 0.6],
        [1.0, 1.0],
        [0.0, 1.0],
    ]

    private static let four: [SIMD2<Double>] = [
        [0.7, 1.0],
        [0.7, 0.0],
        [0.0, 0.5],
        [1.0, 0.5],
    ]

    private static let five: [SIMD2<Double>] = [
        [1.0, 0.0],
        [0.0, 0.0],
        [0.0, 0.3],
        [1.0, 0.6],
        [1.0, 1.0],
        [0.0, 1.0],
    ]

    private static let six: [SIMD2<Double>] = [
        [0.0, 0.0],
        [0.0, 1.0],
        [1.0, 1.0],
        [1.0, 0.6],
        [0.0, 0.5],
    ]

    private static let seven: [SIMD2<Double>] = [
        [0.0, 0.0],
        [1.0, 0.0],
        [1.0, 0.3],
        [0.0, 1.0],
    ]

    private static let eight: [SIMD2<Double>] = [
        [0.0, 0.4],
        [0.0, 0.0],
        [1.0, 0.0],
        [1.0, 1.0],
        [0.0, 1.0],
        [0.0, 0.4],
        [1.0, 0.4],
    ]

    private static let nine: [SIMD2<Double>] = [
        [1.0, 1.0],
        [1.0, 0.0],
        [0.0, 0.0],
        [0.0, 0.5],
        [1.0, 0.6],
    ]
}
