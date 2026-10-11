@testable import CanvasRender
import Foundation
import simd
import Testing

/// World space is CAD-style: X+ right, Y+ forward, Z+ up. The 2D output is y-up.
struct CoordinateSystemTests {
    let canvasSize = Vector2D(1000, 800)

    func project(_ point: Vector, _ camera: Camera) -> Vector2D {
        OrthographicTransform(camera: camera).apply(point: point, canvasSize: canvasSize)
    }

    func expectClose(_ a: Vector2D, _ b: Vector2D, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(simd_distance(a, b) < 1e-9, "\(a) != \(b)", sourceLocation: sourceLocation)
    }

    func expectClose(_ a: Vector, _ b: Vector, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(simd_distance(a, b) < 1e-9, "\(a) != \(b)", sourceLocation: sourceLocation)
    }

    @Test func presetsShowTheExpectedAxes() {
        // (camera, world axis shown to the right, world axis shown up, viewing direction)
        let views: [(Camera, Vector, Vector, Vector)] = [
            (.top(), [1, 0, 0], [0, 1, 0], [0, 0, -1]),
            (.bottom(), [1, 0, 0], [0, -1, 0], [0, 0, 1]),
            (.front(), [1, 0, 0], [0, 0, 1], [0, 1, 0]),
            (.back(), [-1, 0, 0], [0, 0, 1], [0, -1, 0]),
            (.right(), [0, 1, 0], [0, 0, 1], [-1, 0, 0]),
            (.left(), [0, -1, 0], [0, 0, 1], [1, 0, 0]),
        ]
        for (camera, right, up, direction) in views {
            expectClose(project(right, camera), [1, 0])
            expectClose(project(up, camera), [0, 1])
            expectClose(OrthographicTransform(camera: camera).cameraDirection, direction)
            // right-handed: right x forward = up
            expectClose(right.cross(direction), up)
        }
        #expect(OrthographicTransform(camera: .top()).isTopDownOrthographic)
        #expect(!OrthographicTransform(camera: .front()).isTopDownOrthographic)
    }

    @Test func topCameraMatchesTheHistoricalExportCamera() {
        // The camera every DXF export has used: it must stay exactly a top view.
        let export = Camera(position: Vector(0, 0, 200), rotation: Quat(angle: -.pi * 0.5, axis: Vector(1, 0, 0)))
        for point: Vector in [[3, 4, 5], [-10, 2.5, 0], [0, 0, -7]] {
            #expect(project(point, export) == project(point, .top()))
            expectClose(project(point, .top()), [point.x, point.y])
        }
    }

    @Test func lookAtMatchesPresets() {
        let presets: [(Camera, Camera)] = [
            (Camera(eye: [0, -200, 0], target: .zero), .front()),
            (Camera(eye: [200, 0, 0], target: .zero), .right()),
            (Camera(eye: [0, 0, 200], target: .zero, up: [0, 1, 0]), .top()),
        ]
        for (lookAt, preset) in presets {
            for point: Vector in [[1, 0, 0], [0, 1, 0], [0, 0, 1]] {
                expectClose(project(point, lookAt), project(point, preset))
            }
        }
    }

    @Test func perspectiveLooksForwardWithoutMirroring() {
        let camera = Camera(eye: [0, -100, 0], target: .zero)
        let transform = PerspectiveTransform(camera: camera)
        let center = transform.apply(point: [0, 0, 0], canvasSize: canvasSize)
        let right = transform.apply(point: [10, 0, 0], canvasSize: canvasSize)
        let up = transform.apply(point: [0, 0, 10], canvasSize: canvasSize)
        let far = transform.apply(point: [10, 100, 0], canvasSize: canvasSize)
        expectClose(center, [0, 0])
        #expect(right.x > 0 && abs(right.y) < 1e-9)
        #expect(up.y > 0 && abs(up.x) < 1e-9)
        #expect(far.x > 0 && far.x < right.x) // further away is smaller
        // unapply is the inverse of apply
        let ray = transform.unapply(point: right, canvasSize: canvasSize)
        expectClose(ray.point + ray.direction * 100.498756211208902, [10, 0, 0])
    }

    @Test func pitchJawRollMatricesAreRotations() {
        for roll in stride(from: -3.0, through: 3.0, by: 0.7) {
            #expect(abs(simd_double3x3(pitch: 0.3, jaw: -0.2, roll: roll).determinant - 1) < 1e-12)
            #expect(abs(simd_double4x4(pitch: 0.3, jaw: -0.2, roll: roll).determinant - 1) < 1e-12)
        }
    }
}
