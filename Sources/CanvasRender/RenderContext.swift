import CoreGraphics
import Foundation
import simd
import SwiftUI

public struct RenderContext {
    let renderTarget: RenderTarget
    let color: Color
    let lineWidth: Double
    let lineStyle: Decoration.LineStyle
    let transform2d: CGAffineTransform
    let transform3d: RenderTransformer
    let canvasSize: Vector2D

    public init(canvasSize: Vector2D, renderTarget: RenderTarget, color: Color, lineWidth: Double, lineStyle: Decoration.LineStyle, transform2d: CGAffineTransform, transform3d: RenderTransformer) {
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
}

public struct AxisAlignedOrthographicTransform: RenderTransformer {
    private let plane: AxisPlane
    public init(plane: AxisPlane) {
        self.plane = plane
    }

    public func apply(point: Vector, canvasSize: Vector2D) -> Vector2D {
        return plane.convert(point)
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

    public func apply(point: Vector, canvasSize: Vector2D) -> Vector2D {
        let projectionMatrix = orthoProjectionMatrix(width: canvasSize.x, height: canvasSize.y, zNear: 0, zFar: 800)
        let modelViewMatrix = viewSpaceMatrix(eye: camera.position, rotation: camera.rotation)
        let worldPosition = translationMatrix(pos: point)
        let clipSpace = projectionMatrix * modelViewMatrix * worldPosition
        let screenSpace = Vector2D(clipSpace.columns.3.x, clipSpace.columns.3.y) * canvasSize

        return screenSpace
    }

    private func translationMatrix(pos: Vector) -> simd_double4x4 {
        return simd_double4x4(rows: [
            simd_double4(1, 0, 0, pos.x),
            simd_double4(0, 1, 0, pos.y),
            simd_double4(0, 0, 1, pos.z),
            simd_double4(0, 0, 0, 1),
        ])
    }

    private func viewSpaceMatrix(eye: Vector, rotation: Quat) -> simd_double4x4 {
        let right = rotation.inverse.act(Vector(1, 0, 0))
        let forward = rotation.inverse.act(Vector(0, 1, 0))
        let up = rotation.inverse.act(Vector(0, 0, 1))

        let vewMatrix = simd_double4x4(rows: [
            simd_double4(right.x, forward.x, up.x, eye.x), // simd_double4(right.x, up.x, forward.x, eye.x),
            simd_double4(right.y, forward.y, up.y, eye.y), // simd_double4(right.y, up.y, forward.y, eye.y),
            simd_double4(right.z, forward.z, up.z, eye.z), // simd_double4(right.z, up.z, forward.z, eye.z),
            simd_double4(0, 0, 0, 1),
        ])
        return vewMatrix
    }

    private func orthoProjectionMatrix(width: Double, height: Double, zNear: Double, zFar: Double) -> simd_double4x4 {
        let aspect = 1.0
        let orthoMatrix = simd_double4x4(rows: [
            simd_double4(1 / aspect / width, 0, 0, 0),
            simd_double4(0, 1 / height, 0, 0),
            simd_double4(0, 0, -(2 / (zFar - zNear)), -(((zFar + zNear) * 2) / (zFar - zNear))),
            simd_double4(0, 0, 0, 1),
        ])
        return orthoMatrix
    }
}

public protocol PerspectiveCamera {
    var rotation: Quat { get }
    var position: Vector { get }
}

public struct PerspectiveTransform: RenderTransformer {
    private let camera: PerspectiveCamera
    public init(camera: PerspectiveCamera) {
        self.camera = camera
    }

    public func apply(point: Vector, canvasSize: Vector2D) -> Vector2D {
        // let perspectiveMatrix = orthographicPerspectiveMatrix(fov: .pi / 2, aspect: 1.0, near: 0.1, far: 100)
        let perspectiveMatrix = perspectiveMatrix(angleOfView: .pi / 2,
                                                  imageWidth: canvasSize.x,
                                                  imageHeight: canvasSize.y,
                                                  near: 100,
                                                  far: 200)

        // transform into opgl coordinates
        let eyePosition = Vector(x: camera.position.x, y: camera.position.z, z: -camera.position.y)
        let cameraDirection = camera.rotation.act(Vector(0, 1, 0))
        let viewMatrix = lookDirection(eye: eyePosition, direction: Vector(x: cameraDirection.x,
                                                                           y: cameraDirection.z,
                                                                           z: -cameraDirection.y),
                                       up: [0, 1, 0])
        // let viewMatrix = lookAt(eye: cameraPosition, center: [0, 0, 0], up: [0, 1, 0])
        // let rasterCoordinate = perspectiveMatrix * viewMatrix

        let pointInCameraCoordinate = Vector(x: point.x, y: point.z, z: -point.y)
        let normalizedCoordinate = multiplyMatrix(multiplyMatrix(pointInCameraCoordinate, viewMatrix), perspectiveMatrix)

        // convert to raster space and mark the position of the vertex in the image with a simple dot
        let x = min(canvasSize.x - 1, (normalizedCoordinate.x + 1) * 0.5 * canvasSize.x)
        let y = min(canvasSize.y - 1, (1 - (normalizedCoordinate.y + 1) * 0.5) * canvasSize.y)

        //  return Vector2D(x, y)
        return (normalizedCoordinate * simd_double3(canvasSize, 1)).xy
    }

    public var cameraDirection: Vector {
        return Vector(0, 0, -1)
    }

    private func multiplyMatrix(_ vector: Vector, _ matrix: simd_double4x4) -> Vector {
        var x = vector.x * matrix[0][0] + vector.y * matrix[1][0] + vector.z * matrix[2][0] + /* vector.z = 1 */ matrix[3][0]
        var y = vector.x * matrix[0][1] + vector.y * matrix[1][1] + vector.z * matrix[2][1] + /* vector.z = 1 */ matrix[3][1]
        var z = vector.x * matrix[0][2] + vector.y * matrix[1][2] + vector.z * matrix[2][2] + /* vector.z = 1 */ matrix[3][2]
        let w = vector.x * matrix[0][3] + vector.y * matrix[1][3] + vector.z * matrix[2][3] + /* vector.z = 1 */ matrix[3][3]

        // normalize if w is different than 1 (convert from homogeneous to Cartesian coordinates)
        if w != 1 {
            x /= w
            y /= w
            z /= w
        }

        return Vector(x, y, z)
    }

    // https://github.com/adriankrupa/swift3D/blob/master/Source/Matrix_Transform.swift#L213C1-L226C2
    private func orthographicPerspectiveMatrix(fov: Double, aspect: Double, near: Double, far: Double) -> simd_double4x4 {
        assert(abs(aspect) > Double(0), "")

        /*
         let tanHalfFovy = tan(fovy / 2.0)
         var result = simd_double4x4(0)
         result[0][0] = 1.0 / (aspect * tanHalfFovy)
         result[1][1] = 1.0 / tanHalfFovy
         result[2][2] = -(zFar + zNear) / (zFar - zNear)
         result[2][3] = -1.0
         result[3][2] = -(2.0 * zFar * zNear) / (zFar - zNear)
         return result
         */

        let scale = 1.0 / tan(fov * 0.5)
        var result = simd_double4x4(0)
        result[0][0] = scale // scale the x coordinates of the projected point
        result[1][1] = scale // scale the y coordinates of the projected point
        result[2][2] = -far / (far - near) // used to remap z to [0,1]
        result[3][2] = -far * near / (far - near) // used to remap z [0,1]
        result[2][3] = -1 // set w = -z
        result[3][3] = 0

        return result
    }

    private func perspectiveMatrix(angleOfView: Double,
                                   imageWidth: Double,
                                   imageHeight: Double,
                                   near: Double,
                                   far: Double) -> simd_double4x4 {
        let imageAspectRatio = imageWidth / imageHeight
        let scale = tan(angleOfView * 0.5) * near
        let right = imageAspectRatio * scale
        let left = -right
        let top = scale
        let bottom = -top

        // openGL perspective projection matrix
        var matrix = simd_double4x4(0.0)

        matrix[0][0] = 2.0 * near / (right - left)
        matrix[0][1] = 0.0
        matrix[0][2] = 0.0
        matrix[0][3] = 0.0

        matrix[1][0] = 0.0
        matrix[1][1] = 2.0 * near / (top - bottom)
        matrix[1][2] = 0.0
        matrix[1][3] = 0.0

        matrix[2][0] = (right + left) / (right - left)
        matrix[2][1] = (top + bottom) / (top - bottom)
        matrix[2][2] = -(far + near) / (far - near)
        matrix[2][3] = -1.0

        matrix[3][0] = 0.0
        matrix[3][1] = 0.0
        matrix[3][2] = -2.0 * far * near / (far - near)
        matrix[3][3] = 0.0

        return matrix
    }

    @warn_unused_result
    public func lookAt(eye: Vector, center: Vector, up: Vector) -> simd_double4x4 {
        let f = simd_normalize(center - eye)
        let s = simd_normalize(simd_cross(f, up))
        let u = simd_cross(s, f)

        var result = simd_double4x4(1)
        result[0][0] = s.x
        result[1][0] = s.y
        result[2][0] = s.z
        result[0][1] = u.x
        result[1][1] = u.y
        result[2][1] = u.z
        result[0][2] = -f.x
        result[1][2] = -f.y
        result[2][2] = -f.z
        result[3][0] = -dot(s, eye)
        result[3][1] = -dot(u, eye)
        result[3][2] = dot(f, eye)

        return result
    }

    public func lookDirection(eye: Vector, direction: Vector, up: Vector) -> simd_double4x4 {
        let f = direction
        let s = simd_normalize(simd_cross(f, up))
        let u = simd_cross(s, f)

        var result = simd_double4x4(1)
        result[0][0] = s.x
        result[1][0] = s.y
        result[2][0] = s.z
        result[0][1] = u.x
        result[1][1] = u.y
        result[2][1] = u.z
        result[0][2] = -f.x
        result[1][2] = -f.y
        result[2][2] = -f.z
        result[3][0] = -dot(s, eye)
        result[3][1] = -dot(u, eye)
        result[3][2] = dot(f, eye)
        return result
    }

    /// Builds a rotation 4 * 4 matrix created from an axis vector and an angle.
    @warn_unused_result
    private func rotate(m: double4x4, angle: Double, axis: double3) -> double4x4 {
        let a = angle
        let c = cos(a)
        let s = sin(a)

        let v = normalize(axis)
        let temp = (1 - c) * v

        var Rotate = double4x4(0)
        Rotate[0][0] = c + temp[0] * v[0]
        Rotate[0][1] = 0 + temp[0] * v[1] + s * v[2]
        Rotate[0][2] = 0 + temp[0] * v[2] - s * v[1]

        Rotate[1][0] = 0 + temp[1] * v[0] - s * v[2]
        Rotate[1][1] = c + temp[1] * v[1]
        Rotate[1][2] = 0 + temp[1] * v[2] + s * v[0]

        Rotate[2][0] = 0 + temp[2] * v[0] + s * v[1]
        Rotate[2][1] = 0 + temp[2] * v[1] - s * v[0]
        Rotate[2][2] = c + temp[2] * v[2]

        var Result = double4x4(0)
        Result[0] = m[0] * Rotate[0][0] + m[1] * Rotate[0][1] + m[2] * Rotate[0][2]
        Result[1] = m[0] * Rotate[1][0] + m[1] * Rotate[1][1] + m[2] * Rotate[1][2]
        Result[2] = m[0] * Rotate[2][0] + m[1] * Rotate[2][1] + m[2] * Rotate[2][2]
        Result[3] = m[3]
        return Result
    }

    /// Builds a translation 4 * 4 matrix created from a vector of 3 components.
    @warn_unused_result
    public func translate(m: double4x4, v: double3) -> double4x4 {
        var result = m
        let vv = double4(v.x, v.y, v.z, 1)
        result[3] = m * vv
        return result
    }
}
