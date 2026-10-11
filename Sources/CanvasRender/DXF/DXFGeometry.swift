import CoreGraphics
import Foundation

/// The stroke style of exported geometry. Every distinct style becomes its own DXF layer.
public struct DXFStyle: Hashable, Sendable {
    public var color: CanvasColor
    /// Dash pattern (dash, gap, dash, ...) in drawing units; empty for a solid line.
    public var dash: [Double]

    public init(color: CanvasColor, dash: [Double] = []) {
        self.color = color
        self.dash = dash
    }

    public var isDashed: Bool {
        !dash.isEmpty
    }
}

/// A straight line or circular arc in drawing (canvas) coordinates.
public enum DXFSegment: Sendable {
    case line(from: CGPoint, to: CGPoint)
    /// A circular arc starting at `startAngle` and sweeping `sweep` radians, counterclockwise when positive.
    case arc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, sweep: CGFloat)

    public var startPoint: CGPoint {
        switch self {
        case let .line(from, _):
            return from
        case let .arc(center, radius, startAngle, _):
            return CGPoint(x: center.x + radius * cos(startAngle), y: center.y + radius * sin(startAngle))
        }
    }

    public var endPoint: CGPoint {
        switch self {
        case let .line(_, to):
            return to
        case let .arc(center, radius, startAngle, sweep):
            return CGPoint(x: center.x + radius * cos(startAngle + sweep), y: center.y + radius * sin(startAngle + sweep))
        }
    }

    /// The same segment traversed in the opposite direction.
    public var reversed: DXFSegment {
        switch self {
        case let .line(from, to):
            return .line(from: to, to: from)
        case let .arc(center, radius, startAngle, sweep):
            return .arc(center: center, radius: radius, startAngle: startAngle + sweep, sweep: -sweep)
        }
    }

    /// The DXF bulge of the segment when it starts at a polyline vertex: tan(sweep / 4), 0 for lines.
    public var bulge: Double {
        switch self {
        case .line:
            return 0
        case let .arc(_, _, _, sweep):
            return tan(sweep / 4)
        }
    }

    /// Points along the segment, including both end points, at most `maxStep` radians apart on arcs.
    public func points(maxStep: CGFloat = .pi / 32) -> [CGPoint] {
        switch self {
        case let .line(from, to):
            return [from, to]
        case let .arc(center, radius, startAngle, sweep):
            let steps = max(1, Int((abs(sweep) / maxStep).rounded(.up)))
            return (0 ... steps).map { step in
                let angle = startAngle + sweep * CGFloat(step) / CGFloat(steps)
                return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            }
        }
    }
}

/// Connected segments (each starting where the previous one ends) drawn with one style.
public struct DXFPolyline: Sendable {
    public let style: DXFStyle
    public let segments: [DXFSegment]
    /// The last segment ends where the first one starts.
    public let closed: Bool
}

public struct DXFCircle: Sendable {
    public let style: DXFStyle
    public let center: CGPoint
    public let radius: CGFloat
}

/// Joins open chains of segments that share end points (within `tolerance`) into longer chains, per style.
///
/// Uses a grid index on the chain end points, so adding a chain costs O(1) instead of a scan over all
/// open chains.
struct PolylineJoiner {
    private final class Chain {
        let style: DXFStyle
        let group: Int
        var segments: [DXFSegment]
        var alive = true

        init(style: DXFStyle, group: Int, segments: [DXFSegment]) {
            self.style = style
            self.group = group
            self.segments = segments
        }

        var head: CGPoint { segments[0].startPoint }
        var tail: CGPoint { segments[segments.count - 1].endPoint }
    }

    private struct Cell: Hashable {
        let x: Int
        let y: Int
    }

    let tolerance: CGFloat
    private let cellSize: CGFloat
    private var openChains: [Chain] = []
    private var index: [Cell: [Int]] = [:]
    private(set) var closed: [DXFPolyline] = []
    /// Chains from different groups are never joined.
    private(set) var group = 0

    init(tolerance: CGFloat) {
        self.tolerance = tolerance
        self.cellSize = tolerance * 4
    }

    var open: [DXFPolyline] {
        openChains.filter(\.alive).map { DXFPolyline(style: $0.style, segments: $0.segments, closed: false) }
    }

    mutating func startNewGroup() {
        group += 1
    }

    mutating func addClosed(_ segments: [DXFSegment], style: DXFStyle) {
        closed.append(DXFPolyline(style: style, segments: segments, closed: true))
    }

    mutating func addOpen(_ segments: [DXFSegment], style: DXFStyle) {
        var chainIndex = openChains.count
        var chain = Chain(style: style, group: group, segments: segments)
        openChains.append(chain)

        while let (otherIndex, other) = findNeighbor(of: chain, excluding: chainIndex) {
            removeFromIndex(otherIndex, other)

            // grow the older chain, keeping its position in the output
            if close(other.tail, chain.head) {
                other.segments += chain.segments
            } else if close(chain.tail, other.head) {
                other.segments = chain.segments + other.segments
            } else if close(other.head, chain.head) {
                other.segments = chain.segments.reversed().map(\.reversed) + other.segments
            } else {
                other.segments += chain.segments.reversed().map(\.reversed)
            }
            chain.alive = false
            chain = other
            chainIndex = otherIndex

            if close(chain.head, chain.tail) {
                chain.alive = false
                closed.append(DXFPolyline(style: chain.style, segments: chain.segments, closed: true))
                return
            }
        }
        addToIndex(chainIndex, chain)
    }

    private func close(_ a: CGPoint, _ b: CGPoint) -> Bool {
        hypot(a.x - b.x, a.y - b.y) < tolerance
    }

    private func cell(_ point: CGPoint) -> Cell {
        func index(_ value: CGFloat) -> Int {
            let cell = (value / cellSize).rounded(.down)
            // far away points share the outermost cells; they are still compared by distance
            return Int(min(max(cell, -1e15), 1e15))
        }
        return Cell(x: index(point.x), y: index(point.y))
    }

    private func findNeighbor(of chain: Chain, excluding excluded: Int) -> (Int, Chain)? {
        var best: Int?
        for point in [chain.head, chain.tail] {
            let center = cell(point)
            for dx in -1 ... 1 {
                for dy in -1 ... 1 {
                    for candidate in index[Cell(x: center.x + dx, y: center.y + dy)] ?? [] where candidate != excluded {
                        let other = openChains[candidate]
                        guard other.alive, other.style == chain.style, other.group == chain.group else {
                            continue
                        }
                        guard close(other.tail, chain.head) || close(chain.tail, other.head)
                            || close(other.head, chain.head) || close(other.tail, chain.tail)
                        else {
                            continue
                        }
                        best = min(best ?? candidate, candidate)
                    }
                }
            }
        }
        return best.map { ($0, openChains[$0]) }
    }

    private mutating func addToIndex(_ chainIndex: Int, _ chain: Chain) {
        index[cell(chain.head), default: []].append(chainIndex)
        index[cell(chain.tail), default: []].append(chainIndex)
    }

    private mutating func removeFromIndex(_ chainIndex: Int, _ chain: Chain) {
        index[cell(chain.head)]?.removeAll { $0 == chainIndex }
        index[cell(chain.tail)]?.removeAll { $0 == chainIndex }
    }
}
