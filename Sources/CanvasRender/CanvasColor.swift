import CoreGraphics
import Foundation
import SwiftUI

public struct CanvasColor: Equatable {
    public static let black = CanvasColor(0, 0, 0, 1)
    public static let white = CanvasColor(1, 1, 1, 1)
    public static let yellow = CanvasColor(1, 0.8, 0, 1)
    public static let cyan = CanvasColor(0, 1, 1, 1)
    public static let red = CanvasColor(1, 0, 0, 1)
    public static let green = CanvasColor(0, 1, 0, 1)
    public static let blue = CanvasColor(0, 0, 1, 1)
    public static let orange = CanvasColor(1, 140 / 255, 0, 1)
    public static let pink = CanvasColor(1, 192 / 255, 203 / 255, 1)
    public static let indigo = CanvasColor(75 / 255, 0, 130 / 255, 1)
    public static let gray = CanvasColor(0.5, 0.5, 0.5, 1)
    public static let purple = CanvasColor(0.5, 0, 0.5, 1)
    public static let mint = CanvasColor(64 / 255, 224 / 255, 208 / 255, 1)

    let r: Double
    let g: Double
    let b: Double
    let a: Double

    public init(red r: Double, green g: Double, blue b: Double, alpha a: Double) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    public func opacity(_ value: Double) -> CanvasColor {
        return CanvasColor(red: r, green: g, blue: b, alpha: a * value)
    }

    var cgColor: CGColor {
        CGColor(red: r, green: g, blue: b, alpha: a)
    }
}
