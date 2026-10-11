import CoreGraphics
import Foundation

/// Draws polylines and circles into a single-page PDF at 1:1 scale, one drawing unit being one millimeter.
struct PDFWriter {
    let polylines: [DXFPolyline]
    let circles: [DXFCircle]

    private static let pointsPerMillimeter: CGFloat = 72 / 25.4

    func document(margin: CGFloat, lineWidth: CGFloat) -> Data {
        var bounds = CGRect.null
        for polyline in polylines {
            for segment in polyline.segments {
                for point in segment.points() {
                    bounds = bounds.union(CGRect(origin: point, size: .zero))
                }
            }
        }
        for circle in circles {
            bounds = bounds.union(CGRect(x: circle.center.x - circle.radius, y: circle.center.y - circle.radius,
                                         width: circle.radius * 2, height: circle.radius * 2))
        }
        if bounds.isNull {
            bounds = .zero
        }
        bounds = bounds.insetBy(dx: -margin, dy: -margin)

        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: bounds.width * Self.pointsPerMillimeter, height: bounds.height * Self.pointsPerMillimeter)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, [kCGPDFContextCreator: "CanvasRender"] as CFDictionary)
        else {
            return Data()
        }

        context.beginPDFPage(nil)
        context.scaleBy(x: Self.pointsPerMillimeter, y: Self.pointsPerMillimeter)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)
        context.setLineWidth(lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        for polyline in polylines {
            apply(polyline.style, to: context)
            context.beginPath()
            context.move(to: polyline.segments[0].startPoint)
            for segment in polyline.segments {
                switch segment {
                case let .line(_, to):
                    context.addLine(to: to)
                case let .arc(center, radius, startAngle, sweep):
                    context.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: startAngle + sweep, clockwise: sweep < 0)
                }
            }
            if polyline.closed {
                context.closePath()
            }
            context.strokePath()
        }
        for circle in circles {
            apply(circle.style, to: context)
            context.strokeEllipse(in: CGRect(x: circle.center.x - circle.radius, y: circle.center.y - circle.radius,
                                             width: circle.radius * 2, height: circle.radius * 2))
        }

        context.endPDFPage()
        context.closePDF()
        return data as Data
    }

    private func apply(_ style: DXFStyle, to context: CGContext) {
        context.setStrokeColor(style.color.cgColor)
        context.setLineDash(phase: 0, lengths: style.dash.map { CGFloat($0) })
    }
}
