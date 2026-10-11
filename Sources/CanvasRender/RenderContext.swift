import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct RenderContext {
    public let renderTarget: RenderTarget
    public let color: CanvasColor
    public let lineWidth: Double
    public let lineStyle: Decoration.LineStyle
    public let transform2d: CGAffineTransform
    public let transform3d: RenderTransformer
    public let canvasSize: Vector2D

    public init(canvasSize: Vector2D, renderTarget: RenderTarget, color: CanvasColor, lineWidth: Double, lineStyle: Decoration.LineStyle, transform2d: CGAffineTransform, transform3d: RenderTransformer) {
        self.canvasSize = canvasSize
        self.renderTarget = renderTarget
        self.color = color
        self.lineWidth = lineWidth
        self.lineStyle = lineStyle
        self.transform2d = transform2d
        self.transform3d = transform3d
    }

    public init(canvasSize: Vector2D, renderTarget: RenderTarget, transform2d: CGAffineTransform, transform3d: RenderTransformer) {
        self.canvasSize = canvasSize
        self.renderTarget = renderTarget
        self.color = .black
        self.lineWidth = 1
        self.lineStyle = .solid
        self.transform2d = transform2d
        self.transform3d = transform3d
    }

    public func transform(_ vector: Vector) -> CGPoint {
        let transformed3d = transform3d.apply(point: vector, canvasSize: canvasSize)
        let cgPoint = transformed3d.cgPoint
        let transformedCGPoint = cgPoint.applying(transform2d)
        return transformedCGPoint
    }
}

/// Projects world space onto the 2D drawing plane.
///
/// World space is CAD-style and right-handed: X+ right, Y+ forward (away from the viewer), Z+ up.
/// The 2D output is y-up: a top view shows world X to the right and world Y upwards.
public protocol RenderTransformer {
    func apply(point: Vector, canvasSize: Vector2D) -> Vector2D
    func unapply(point: Vector2D, canvasSize: Vector2D) -> Ray

    /// The direction the camera looks in, in world space.
    var cameraDirection: Vector { get }

    /// Special case for paper drawing: an orthographic top view, looking from Z+ towards Z-.
    var isTopDownOrthographic: Bool { get }
}

public struct AxisAlignedOrthographicTransform: RenderTransformer {
    private let plane: AxisPlane
    public init(plane: AxisPlane) {
        self.plane = plane
    }

    public func apply(point: Vector, canvasSize: Vector2D) -> Vector2D {
        return plane.convert(point)
    }

    public func unapply(point: Vector2D, canvasSize: Vector2D) -> Ray {
        fatalError("not implemented")
    }

    public var isTopDownOrthographic: Bool {
        switch plane {
        case .xy: true
        default: false
        }
    }

    public var cameraDirection: Vector {
        switch plane {
        case .xy:
            return Vector(0, 0, -1)
        case .xz:
            return Vector(0, 1, 0)
        case .yz:
            // world Y to the right and Z up means looking from X+ towards X-
            return Vector(-1, 0, 0)
        }
    }
}

public class RenderTransform2D {
    public var transform: CGAffineTransform
    init(transform: CGAffineTransform) {
        self.transform = transform
    }
}

public struct OrthographicTransform: RenderTransformer {
    private let camera: PerspectiveCamera
    public init(camera: PerspectiveCamera) {
        self.camera = camera
    }

    public var cameraDirection: Vector {
        return camera.rotation.act(Vector(0, 1, 0))
    }

    public var isTopDownOrthographic: Bool {
        return cameraDirection.dot(Vector(0, 0, -1)) >= 1.0 - 1e-12
    }

    public func apply(point: Vector, canvasSize: Vector2D) -> Vector2D {
        let zoom = 0.5 // 0.5 makes the export work

        let modelMatrix = Matrices.translationMatrix(pos: point)
        let viewMatrix = Matrices.viewSpaceMatrix(eye: camera.position, rotation: camera.rotation)
        let projectionMatrix = Matrices.orthoProjectionMatrix(width: canvasSize.x, height: canvasSize.y, zNear: 1, zFar: 20)

        let clipSpace = projectionMatrix * viewMatrix * modelMatrix
        // let screenSpace = Vector2D(clipSpace.columns.3.x, clipSpace.columns.3.y) * canvasSize

        // homogenous coordinates to cartesian
        //  let cartesian = Vector2D(-clipSpace.columns.3.x / clipSpace.columns.3.w, -clipSpace.columns.3.y / clipSpace.columns.3.w)
        let cartesian = Vector2D(clipSpace.columns.3.x, clipSpace.columns.3.y)

        let screenSpace = cartesian * canvasSize * zoom
        return screenSpace
    }

    public func unapply(point: Vector2D, canvasSize: Vector2D) -> Ray {
        fatalError("not implemented")
    }
}

public class OffsettingTransformer: RenderTransformer {
    public var transform: CGAffineTransform
    public let parent: RenderTransformer

    public var cameraDirection: Vector {
        parent.cameraDirection
    }

    public var isTopDownOrthographic: Bool {
        parent.isTopDownOrthographic
    }

    public init(parent: RenderTransformer, transform: CGAffineTransform) {
        self.transform = transform
        self.parent = parent
    }

    public func unapply(point: Vector2D, canvasSize: Vector2D) -> Ray {
        let transformed = point.cgPoint.applying(transform.inverted())
        let position = parent.unapply(point: Vector2D(x: transformed.x, y: transformed.y),
                                      canvasSize: canvasSize)
        return position
    }

    public func apply(point: Vector, canvasSize: Vector2D) -> Vector2D {
        let position = parent.apply(point: point, canvasSize: canvasSize)
        let transformed = position.cgPoint.applying(transform)
        return Vector2D(x: transformed.x, y: transformed.y)
    }
}

public struct PerspectiveTransform: RenderTransformer {
    private let camera: PerspectiveCamera
    public init(camera: PerspectiveCamera) {
        self.camera = camera
    }

    /// Vertical field of view.
    static let fovY = Double.pi * 0.4

    public var cameraDirection: Vector {
        return camera.rotation.act(Vector(0, 1, 0))
    }

    public var isTopDownOrthographic: Bool {
        return false
    }

    /// Pixels per unit of view-space distance at depth 1.
    private func focalLength(canvasSize: Vector2D) -> Double {
        canvasSize.y * 0.5 / tan(Self.fovY / 2)
    }

    /// Canvas position (origin at the canvas center, y up) of a world point. Points behind the camera are not
    /// clipped and end up mirrored through the center.
    public func apply(point: Vector, canvasSize: Vector2D) -> Vector2D {
        let basis = CameraBasis(camera)
        let relative = point - camera.position
        let depth = relative.dot(basis.forward)
        let scale = focalLength(canvasSize: canvasSize) / depth
        return Vector2D(relative.dot(basis.right) * scale, relative.dot(basis.up) * scale)
    }

    /// The ray from the camera through a canvas position (origin at the canvas center, y up).
    public func unapply(point: Vector2D, canvasSize: Vector2D) -> Ray {
        let basis = CameraBasis(camera)
        let focalLength = focalLength(canvasSize: canvasSize)
        let direction = basis.forward + basis.right * (point.x / focalLength) + basis.up * (point.y / focalLength)
        return Ray(point: camera.position, direction: direction.normalized)
    }
}

/// The world-space axes of a camera: it looks along its local Y+, with local X+ to the right and local Z+ up.
struct CameraBasis {
    let right: Vector
    let forward: Vector
    let up: Vector

    init(_ camera: PerspectiveCamera) {
        self.init(rotation: camera.rotation)
    }

    init(rotation: Quat) {
        self.right = rotation.act(Vector(1, 0, 0))
        self.forward = rotation.act(Vector(0, 1, 0))
        self.up = rotation.act(Vector(0, 0, 1))
    }
}

enum Matrices {
    ///
    ///
    /// Note: These are supposed to be right handed matrices with positive Z up
    ///
    ///

    static func translationMatrix(pos: Vector) -> simd_double4x4 {
        return simd_double4x4(rows: [
            simd_double4(1, 0, 0, pos.x),
            simd_double4(0, 1, 0, pos.y),
            simd_double4(0, 0, 1, pos.z),
            simd_double4(0, 0, 0, 1),
        ])
    }

    static func scaleMatrix(scale: Double) -> simd_double4x4 {
        return simd_double4x4(rows: [
            simd_double4(scale, 0, 0, 0),
            simd_double4(0, scale, 0, 0),
            simd_double4(0, 0, scale, 0),
            simd_double4(0, 0, 0, 1),
        ])
    }

    /// World space to view space: x right, y up, z along the viewing direction.
    static func viewSpaceMatrix(eye: Vector, rotation: Quat) -> simd_double4x4 {
        let basis = CameraBasis(rotation: rotation)
        let right = basis.right
        let forward = basis.forward
        let up = basis.up

        let vewMatrix = simd_double4x4(rows: [
            simd_double4(right.x, right.y, right.z, -simd_dot(eye, right)),
            simd_double4(up.x, up.y, up.z, -simd_dot(eye, up)),
            simd_double4(forward.x, forward.y, forward.z, -simd_dot(eye, forward)),
            simd_double4(0, 0, 0, 1),
        ])
        return vewMatrix
    }

    /* static func orthoProjectionMatrix(width: Double, height: Double, zNear: Double, zFar: Double) -> simd_double4x4 {
         let aspect = 1.0
         let matrix = simd_double4x4(rows: [
             simd_double4(1 / aspect / width, 0, 0, 0),
             simd_double4(0, 1 / height, 0, 0),
             simd_double4(0, 0, -(2 / (zFar - zNear)), -(((zFar + zNear) * 2) / (zFar - zNear))),
             simd_double4(0, 0, 0, 1),
         ])
         return matrix
     } */

    /*
     static func perspectiveProjectionMatrix(width: Double, height: Double, zNear: Double, zFar: Double) -> simd_double4x4 {
     // right handed matrix
     let matrix = simd_double4x4(rows: [
     simd_double4(2 * zNear / width, 0, 0, 0),
     simd_double4(0, 2 * zNear / height, 0, 0),
     simd_double4(0, 0, zFar / (zNear - zFar), -1),
     simd_double4(0, 0, zNear * zFar / (zNear - zFar), 0),
     ])

     return matrix
     }*/

    static func orthoProjectionMatrix(width: Double, height: Double, zNear: Double, zFar: Double) -> simd_double4x4 {
        let matrix = simd_double4x4(rows: [
            simd_double4(2 / width, 0, 0, 0),
            simd_double4(0, 2 / height, 0, 0),
            simd_double4(0, 0, 1 / (zNear - zFar), -1),
            simd_double4(0, 0, zNear / (zNear / zFar), 0),
        ])
        return matrix
    }

}

/// A camera in CAD-style world space (X+ right, Y+ forward, Z+ up).
///
/// The camera looks along its local Y+, with local X+ to the right and local Z+ up. With the identity
/// rotation it is a front view: looking along world Y+, world X to the right and world Z up.
public protocol PerspectiveCamera {
    var rotation: Quat { get }
    var position: Vector { get }
}

/// A fixed camera, with the standard CAD views as presets.
public struct Camera: PerspectiveCamera {
    public var position: Vector
    public var rotation: Quat

    public init(position: Vector, rotation: Quat) {
        self.position = position
        self.rotation = rotation
    }

    /// A camera at `eye` looking at `target`, oriented so `up` points as far up on screen as possible.
    public init(eye: Vector, target: Vector, up: Vector = Vector(0, 0, 1)) {
        self.init(position: eye, rotation: Quat(eye: eye, target: target, up: up))
    }

    /// Looking down along Z-: X right, Y up.
    public static func top(target: Vector = .zero, distance: Double = 200) -> Camera {
        Camera(position: target + Vector(0, 0, distance), rotation: Quat(angle: -.pi / 2, axis: Vector(1, 0, 0)))
    }

    /// Looking up along Z+: X right, Y down.
    public static func bottom(target: Vector = .zero, distance: Double = 200) -> Camera {
        Camera(position: target - Vector(0, 0, distance), rotation: Quat(angle: .pi / 2, axis: Vector(1, 0, 0)))
    }

    /// Looking along Y+: X right, Z up.
    public static func front(target: Vector = .zero, distance: Double = 200) -> Camera {
        Camera(position: target - Vector(0, distance, 0), rotation: .identity)
    }

    /// Looking along Y-: X left, Z up.
    public static func back(target: Vector = .zero, distance: Double = 200) -> Camera {
        Camera(position: target + Vector(0, distance, 0), rotation: Quat(angle: .pi, axis: Vector(0, 0, 1)))
    }

    /// Looking along X- (from the right side): Y right, Z up.
    public static func right(target: Vector = .zero, distance: Double = 200) -> Camera {
        Camera(position: target + Vector(distance, 0, 0), rotation: Quat(angle: .pi / 2, axis: Vector(0, 0, 1)))
    }

    /// Looking along X+ (from the left side): Y left, Z up.
    public static func left(target: Vector = .zero, distance: Double = 200) -> Camera {
        Camera(position: target - Vector(distance, 0, 0), rotation: Quat(angle: -.pi / 2, axis: Vector(0, 0, 1)))
    }
}

/// Lets the presets be written as `OrthographicTransform(camera: .top())`.
public extension PerspectiveCamera where Self == Camera {
    static func top(target: Vector = .zero, distance: Double = 200) -> Camera { Camera.top(target: target, distance: distance) }
    static func bottom(target: Vector = .zero, distance: Double = 200) -> Camera { Camera.bottom(target: target, distance: distance) }
    static func front(target: Vector = .zero, distance: Double = 200) -> Camera { Camera.front(target: target, distance: distance) }
    static func back(target: Vector = .zero, distance: Double = 200) -> Camera { Camera.back(target: target, distance: distance) }
    static func right(target: Vector = .zero, distance: Double = 200) -> Camera { Camera.right(target: target, distance: distance) }
    static func left(target: Vector = .zero, distance: Double = 200) -> Camera { Camera.left(target: target, distance: distance) }
}
