import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct RenderContext {
    let renderTarget: RenderTarget
    let color: CanvasColor
    let lineWidth: Double
    let lineStyle: Decoration.LineStyle
    let transform2d: CGAffineTransform
    let transform3d: RenderTransformer
    let canvasSize: Vector2D

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

    func transform(_ vector: Vector) -> CGPoint {
        let transformed3d = transform3d.apply(point: vector, canvasSize: canvasSize)
        let cgPoint = transformed3d.cgPoint
        let transformedCGPoint = cgPoint.applying(transform2d)
        return transformedCGPoint
    }
}

public protocol RenderTransformer {
    func apply(point: Vector, canvasSize: Vector2D) -> Vector2D
    var cameraDirection: Vector { get }

    /// special case for paper drawing where camera looks down from z+ towards z- with a orthographic rendering
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
            return Vector(1, 0, 0)
        }
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
        return cameraDirection.dot(Vector(0, -1, 0)) == 1.0
    }

    public func apply(point: Vector, canvasSize: Vector2D) -> Vector2D {
        let zoom = 1.0  / 4.0

        let modelMatrix = Matrices.translationMatrix(pos: point)
        let viewMatrix = Matrices.viewSpaceMatrix(eye: camera.position, rotation: camera.rotation)
        let projectionMatrix = Matrices.orthoProjectionMatrix(width: canvasSize.x * zoom, height: canvasSize.y * zoom, zNear: 1, zFar: 20)

        let clipSpace = projectionMatrix * viewMatrix * modelMatrix
        // let screenSpace = Vector2D(clipSpace.columns.3.x, clipSpace.columns.3.y) * canvasSize

        // homogenous coordinates to cartesian
        // let cartesian = Vector2D(-clipSpace.columns.3.x / clipSpace.columns.3.w, -clipSpace.columns.3.y / clipSpace.columns.3.w)
        let cartesian = Vector2D(clipSpace.columns.3.x, clipSpace.columns.3.y)

        let screenSpace = cartesian * canvasSize
        return screenSpace
    }
}

public struct PerspectiveTransform: RenderTransformer {
    private let camera: PerspectiveCamera
    public init(camera: PerspectiveCamera) {
        self.camera = camera
    }

    public var cameraDirection: Vector {
        return camera.rotation.act(Vector(0, 1, 0))
    }

    public var isTopDownOrthographic: Bool {
        return cameraDirection.dot(Vector(0, -1, 0)) == 1.0
    }

    public func apply(point: Vector, canvasSize: Vector2D) -> Vector2D {
        // local to world space
        let modelMatrix = Matrices.translationMatrix(pos: point)
        // world space to camera space
        let viewMatrix = Matrices.viewSpaceMatrix(eye: camera.position, rotation: camera.rotation)
        // camera to screen
        let projectionMatrix = Matrices.perspectiveProjectionMatrix(width: canvasSize.x, height: canvasSize.y, zNear: 1, zFar: 20, fovY: .pi * 0.4)

        let clipSpace = projectionMatrix * viewMatrix * modelMatrix
        // homogenous coordinates to cartesian
        let cartesian = Vector2D(-clipSpace.columns.3.x / clipSpace.columns.3.w, -clipSpace.columns.3.y / clipSpace.columns.3.w)

        let screenSpace = cartesian * canvasSize
        return screenSpace
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

    static func viewSpaceMatrix(eye: Vector, rotation: Quat) -> simd_double4x4 {
        let right = rotation.act(Vector(1, 0, 0))
        let forward = rotation.act(Vector(0, -1, 0))
        let up = rotation.act(Vector(0, 0, 1))

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

    static func perspectiveProjectionMatrix(width: Double, height: Double, zNear: Double, zFar: Double, fovY: Double) -> simd_double4x4 {
        let aspect = width / height
        let t = tan(fovY / 2)
        let x = 1 / (aspect * t)
        let y = 1 / t
        let z = -((zFar + zNear) / (zFar - zNear))
        let w = -((2 * zFar * zNear) / (zFar / zNear))
        // right handed matrix
        let matrix = simd_double4x4(rows: [
            simd_double4(x, 0, 0, 0),
            simd_double4(0, y, 0, 0),
            simd_double4(0, 0, z, -1),
            simd_double4(0, 0, w, 0),
        ])

        return matrix
    }
}

public protocol PerspectiveCamera {
    var rotation: Quat { get }
    var position: Vector { get }
}
