@testable import CanvasRender
import CoreGraphics
import Foundation
import Testing

struct DXFRenderTargetTests {
    @Test func joinsSegmentsOfTheSameStyleIntoPolylines() {
        let target = DXFRenderTarget()
        // a square drawn as four separate strokes, in mixed directions
        for (from, to) in [((0, 0), (10, 0)), ((10, 10), (10, 0)), ((10, 10), (0, 10)), ((0, 0), (0, 10))] {
            target.beginPath(id: nil)
            target.move(to: CGPoint(x: from.0, y: from.1))
            target.addLine(to: CGPoint(x: to.0, y: to.1))
            target.strokePath()
        }
        // a red line touching the square is not joined with it
        target.setStrokeColor(CanvasColor.red.cgColor)
        target.beginPath(id: nil)
        target.move(to: CGPoint(x: 10, y: 0))
        target.addLine(to: CGPoint(x: 20, y: 0))
        target.strokePath()

        #expect(target.polylines.count == 2)
        #expect(target.polylines[0].closed && target.polylines[0].segments.count == 4)
        #expect(target.polylines[0].style.color == .black)
        #expect(!target.polylines[1].closed && target.polylines[1].style.color == .red)
    }

    @Test func groupsAreNotJoined() {
        let target = DXFRenderTarget()
        target.beginPath(id: nil)
        target.move(to: .zero)
        target.addLine(to: CGPoint(x: 1, y: 0))
        target.strokePath()
        target.finishGroup()
        target.beginPath(id: nil)
        target.move(to: CGPoint(x: 1, y: 0))
        target.addLine(to: CGPoint(x: 2, y: 0))
        target.strokePath()
        #expect(target.polylines.count == 2)
    }

    @Test func arcsKeepTheirDirectionWhenJoinedReversed() {
        let target = DXFRenderTarget()
        // quarter circle from (10, 0) to (0, 10), then a line from the origin to its end, reversed when joined
        target.beginPath(id: nil)
        target.arc(center: .zero, radius: 10, startAngle: 0, endAngle: .pi / 2, counterClockwise: true)
        target.strokePath()
        target.beginPath(id: nil)
        target.move(to: CGPoint(x: 0, y: 0))
        target.addLine(to: CGPoint(x: 0, y: 10))
        target.strokePath()

        let polyline = try! #require(target.polylines.first)
        #expect(target.polylines.count == 1)
        let points = polyline.segments.flatMap { $0.points() }
        // every point is on the arc or on the line
        for point in points {
            let onArc = abs(hypot(point.x, point.y) - 10) < 1e-9 && point.x >= -1e-9 && point.y >= -1e-9
            let onLine = abs(point.x) < 1e-9 && point.y >= -1e-9 && point.y <= 10 + 1e-9
            #expect(onArc || onLine, "\(point)")
        }
    }

    @Test func fullArcsAndCirclesBecomeCircles() {
        let target = DXFRenderTarget()
        target.beginPath(id: nil)
        target.arc(center: CGPoint(x: 5, y: 5), radius: 2, startAngle: 0, endAngle: .pi * 2, counterClockwise: true)
        target.closePath()
        target.strokePath()
        target.beginPath(id: nil)
        target.circle(center: CGPoint(x: 1, y: 1), radius: 3)
        target.strokePath()
        #expect(target.polylines.isEmpty)
        #expect(target.circles.map(\.radius) == [2, 3])
    }

    @Test func unstrokedPathsAreDiscarded() {
        let target = DXFRenderTarget()
        target.beginPath(id: nil)
        target.move(to: .zero)
        target.addLine(to: CGPoint(x: 1, y: 0))
        target.beginPath(id: nil)
        target.strokePath()
        #expect(target.polylines.isEmpty)
    }

    @Test func writesLayersPerStyle() {
        let target = DXFRenderTarget()
        target.setLineDash(phase: 0, lengths: [5, 2])
        target.setStrokeColor(CanvasColor.red.cgColor)
        target.beginPath(id: nil)
        target.move(to: .zero)
        target.addLine(to: CGPoint(x: 1, y: 0))
        target.strokePath()
        let dxf = target.dxf()
        #expect(dxf.contains("\n  2\nred-dash-5-2\n"))
        #expect(dxf.contains("\n  2\nDASH_5_2\n"))
        #expect(dxf.contains("\n  9\n$INSUNITS\n 70\n4\n"))
        #expect(DXFWriter.nearestACI(.red) == 1)
        #expect(DXFWriter.nearestACI(.black) == 7)
    }
}

struct DXFRobustnessTests {
    @Test func nonFiniteAndHugeCoordinates() {
        let target = DXFRenderTarget()
        target.beginPath(id: nil)
        target.move(to: CGPoint(x: 0, y: -1.7e20))
        target.addLine(to: CGPoint(x: 1, y: -1.7e20))
        target.addLine(to: CGPoint(x: CGFloat.nan, y: 0))
        target.addLine(to: CGPoint(x: 2, y: 2))
        target.addLine(to: CGPoint(x: 3, y: 2))
        target.strokePath()
        #expect(target.polylines.count == 2)
        #expect(!target.dxf().lowercased().contains("nan"))
    }
}
