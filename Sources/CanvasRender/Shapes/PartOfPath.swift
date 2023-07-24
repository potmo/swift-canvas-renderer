import CoreGraphics
import Foundation
import simd
import SwiftUI


public protocol PartOfPath {
    func drawPartOfPath(in context: CGContext, using transform: CGAffineTransform)
}
