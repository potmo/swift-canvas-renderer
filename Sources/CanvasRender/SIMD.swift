import Foundation
import simd

public typealias Vector2D = simd_double2
public typealias Vector = simd_double3
public typealias Quat = simd_quatd

public extension Vector {
    func intersectPlane(normal: Vector, planeOrigin: Vector, rayOrigin: Vector) -> Vector? {
        let rayDirection = self
        // assuming vectors are all normalized
        let denom = simd_dot(-normal, rayDirection)

        guard denom > 1e-6 else {
            // parallel to plane
            return nil
        }

        let p0l0 = planeOrigin - rayOrigin
        let t = simd_dot(p0l0, -normal) / denom
        return rayOrigin + rayDirection * t
    }

    func intersectPlane2(normal: Vector, planeOrigin: Vector, rayOrigin: Vector) -> Vector? {
        let rayDirection = self
        // assuming vectors are all normalized
        let denom = simd_dot(-normal, rayDirection)

        guard denom > 1e-6 else {
            // parallel to plane
            return nil
        }

        let t = -(rayOrigin.dot(normal) + denom) / rayDirection.dot(normal)
        return rayOrigin + t * rayDirection
    }
}

public extension Vector {
    static func normalFromClockwiseVertices(a: Vector, b: Vector, c: Vector) -> Vector {
        return simd_cross(c - a, b - a).normalized
    }
}

public extension Vector {
    func angleBetween(and other: Vector, around rotationAxis: Vector = Vector(0, 0, 1)) -> Double {
        return atan2(self.normalized.cross(other.normalized).dot(rotationAxis), self.normalized.dot(other.normalized))
    }

    func angleBetween2(and other: Vector) -> Double {
        return acos(self.dot(other) / (self.length / other.length))
    }
}

public extension Vector {
    func rotated(by quat: Quat) -> Vector {
        return quat.act(self)
    }
}

public extension Vector {
    func rotated(by angle: Double, around axis: Axis) -> Vector {
        let quat = Quat(angle: angle, axis: axis.vector)
        return quat.act(self)
    }

    func rotated(by angle: Double, around axis: Axis, pivot: Vector) -> Vector {
        let quat = Quat(angle: angle, axis: axis.vector)
        return quat.act(self - pivot) + pivot
    }
}

public enum Axis {
    case x
    case y
    case z

    var vector: Vector {
        switch self {
        case .x:
            return Vector(1, 0, 0)
        case .y:
            return Vector(0, 1, 0)
        case .z:
            return Vector(0, 0, 1)
        }
    }
}

public enum AxisPlane {
    case xy
    case xz
    case yz

    func convert(_ vector: Vector) -> Vector2D {
        switch self {
        case .xy:
            return Vector2D(vector.x, vector.y)
        case .xz:
            return Vector2D(vector.x, vector.z)
        case .yz:
            return Vector2D(vector.y, vector.z)
        }
    }
}

public extension Vector {
    var negated: Vector {
        return self * -1
    }

    func scaled(by value: Double) -> Vector {
        return self * value
    }

    var normalized: Vector {
        return simd_precise_normalize(self)
    }

    var length: Double {
        return simd_length(self)
    }

    func cross(_ other: Vector) -> Vector {
        return simd_cross(self, other)
    }

    func dot(_ other: Vector) -> Double {
        return simd_dot(self, other)
    }

    func projected(onto other: Vector) -> Vector {
        // let otherNormalized = other.normalized
        // return self.dot(otherNormalized) * otherNormalized
        return project(self, other)
    }
}

public extension simd_double2 {
    var length: Double {
        return simd_length(self)
    }
}

public extension Vector {
    var xyPerp: Vector {
        return self.normalized.cross(Vector(0, 0, 1))
    }
}

public extension Vector {
    var xy: Vector2D {
        return Vector2D(x: x, y: y)
    }

    var xz: Vector2D {
        return Vector2D(x: x, y: z)
    }

    func inPlane(_ plane: AxisPlane) -> Vector2D {
        return plane.convert(self)
    }
}

public extension Vector {
    func with(x: Double) -> Vector {
        return Vector(x, y, z)
    }

    func with(y: Double) -> Vector {
        return Vector(x, y, z)
    }

    func with(z: Double) -> Vector {
        return Vector(x, y, z)
    }
}

public extension Vector2D {
    var cgPoint: CGPoint {
        return CGPoint(x: x, y: y)
    }
}

public extension Double {
    var radiansToDegrees: Double {
        self * 360 / (.pi * 2)
    }

    var degreesToRadians: Double {
        self * .pi * 2 / 360
    }
}

public extension Quat {
    static var identity: Quat {
        return Quat(vector: simd_double4(x: 0, y: 0, z: 0, w: 1))
    }
}
