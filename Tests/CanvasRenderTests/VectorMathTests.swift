@testable import CanvasRender
import Foundation
import simd
import Testing

struct VectorMathTests {
    @Test(arguments: [
        Vector(1, 0, 0), Vector(-1, 0, 0), Vector(0, 1, 0), Vector(0, -1, 0), Vector(0, 0, 1), Vector(0, 0, -1),
        Vector(-0.5, 0.2, 0.8), Vector(3, -3, 3), Vector(1e-3, -2, 5),
    ])
    func arbitraryOrthogonalIsAnOrthogonalUnitVector(vector: Vector) {
        let orthogonal = vector.arbitraryOrthogonal
        #expect(abs(orthogonal.length - 1) < 1e-12)
        #expect(abs(orthogonal.dot(vector.normalized)) < 1e-12)
    }

    @Test func angleBetween2() {
        #expect(abs(Vector(1, 0, 0).angleBetween2(and: Vector(0, 3, 0)) - .pi / 2) < 1e-12)
        #expect(abs(Vector(2, 0, 0).angleBetween2(and: Vector(-5, 0, 0)) - .pi) < 1e-12)
        #expect(Vector(2, 2, 0).angleBetween2(and: Vector(1, 1, 0)) == 0)
    }
}
