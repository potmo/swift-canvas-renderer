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

    func rotated(by quat: Quat, pivot: Vector) -> Vector {
        return quat.act(self - pivot) + pivot
    }

    func rotated(by angle: Double, around axis: Axis) -> Vector {
        let quat = Quat(angle: angle, axis: axis.vector)
        return quat.act(self)
    }

    func rotated(by angle: Double, around axis: Axis, pivot: Vector) -> Vector {
        let quat = Quat(angle: angle, axis: axis.vector)
        return quat.act(self - pivot) + pivot
    }
}

public extension Vector {
    func extended(by amount: Double) -> Vector {
        self.normalized.scaled(by: self.length + amount)
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

    func scalarProjection(onto other: Vector) -> Double {
        return self.dot(other) / other.length
    }

    func projected(ontoPlaneWithNormal normal: Vector) -> Vector {
        return ((1 / pow(normal.length, 2)) * normal).cross(self.cross(normal))
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

public extension Vector {
    var arbitraryOrthogonal: Vector {
        let majorX = (self.x < self.y) && (self.x < self.z) ? 1.0 : 0.0
        let majorY = (self.y <= self.x) && (self.y < self.z) ? 1.0 : 0.0
        let majorZ = (self.z <= self.x) && (self.z <= self.y) ? 1.0 : 0.0

        return self.normalized.cross(Vector(majorX, majorY, majorZ))
    }
}

public extension Vector {
    var isNaN: Bool {
        return x.isNaN || y.isNaN || z.isNaN
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

public extension simd_double4x4 {
    init(pitch: Double, jaw: Double, roll: Double) {
        // positive angles are clockwise
        let pitchRotation = simd_double4x4(rows: [
            simd_double4(1, 0, 0, 0),
            simd_double4(0, cos(pitch), sin(pitch), 0),
            simd_double4(0, -sin(pitch), cos(pitch), 0),
            simd_double4(0, 0, 0, 1),
        ])

        let jawRotation = simd_double4x4(rows: [
            simd_double4(cos(jaw), 0, -sin(jaw), 0),
            simd_double4(0, 1, 0, 0),
            simd_double4(sin(jaw), 0, cos(jaw), 0),
            simd_double4(0, 0, 0, 1),
        ])

        let rollRotation = simd_double4x4(rows: [
            simd_double4(cos(roll), -sin(roll), 0, 0),
            simd_double4(sin(roll), 1, 0, 0),
            simd_double4(0, 0, 1, 0),
            simd_double4(0, 0, 0, 1),
        ])

        // rotate y,z,x here?
        self = jawRotation * rollRotation * pitchRotation
    }

    init(translate translation: simd_double3) {
        self = simd_double4x4(rows: [
            simd_double4(1, 0, 0, translation.x),
            simd_double4(0, 1, 0, translation.y),
            simd_double4(0, 0, 1, translation.z),
            simd_double4(0, 0, 0, 1),
        ])
    }

    init(scale: simd_double1) {
        self = simd_double4x4(rows: [
            simd_double4(scale, 0, 0, 0),
            simd_double4(0, scale, 0, 0),
            simd_double4(0, 0, scale, 0),
            simd_double4(0, 0, 0, scale),
        ])
    }
}

public extension simd_double3x3 {
    init(pitch: Double, jaw: Double, roll: Double) {
        // positive angles are clockwise
        let pitchRotation = simd_double3x3(rows: [
            simd_double3(1, 0, 0),
            simd_double3(0, cos(pitch), sin(pitch)),
            simd_double3(0, -sin(pitch), cos(pitch)),
        ])

        let jawRotation = simd_double3x3(rows: [
            simd_double3(cos(jaw), 0, -sin(jaw)),
            simd_double3(0, 1, 0),
            simd_double3(sin(jaw), 0, cos(jaw)),
        ])

        let rollRotation = simd_double3x3(rows: [
            simd_double3(cos(roll), -sin(roll), 0),
            simd_double3(sin(roll), 1, 0),
            simd_double3(0, 0, 1),
        ])

        // rotate y,z,x here?
        self = jawRotation * pitchRotation * rollRotation
        //   self = pitchRotation * jawRotation * rollRotation
    }
}

public extension Quat {
    init(pitch: Double, jaw: Double, roll: Double) {
        let matrix = simd_double3x3(pitch: pitch, jaw: jaw, roll: roll)
        self = Quat(matrix)
    }
}

public extension Double {
    func toFixed(_ fractionDigits: Int) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = fractionDigits
        numberFormatter.minimumFractionDigits = fractionDigits
        numberFormatter.decimalSeparator = "."

        return numberFormatter.string(from: NSNumber(value: self)) ?? "NaN"
    }
}
