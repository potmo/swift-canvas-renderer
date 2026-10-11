import CoreGraphics
import Foundation

/// Writes polylines and circles as a minimal but complete DXF R2000 (AC1015) document in millimeters.
///
/// The structure (tables, blocks, objects and their handles) follows what ezdxf writes for a new R2000
/// drawing, which AutoCAD and other CAD and laser software read.
struct DXFWriter {
    let polylines: [DXFPolyline]
    let circles: [DXFCircle]

    private struct Layer {
        let name: String
        let aci: Int
        let linetype: String
    }

    private struct Linetype {
        let name: String
        let pattern: [Double]
    }

    // Fixed handles of the document skeleton. Linetypes, layers and entities are numbered from 0x100.
    private enum Handle {
        static let layerTable = 0x1, linetypeTable = 0x2, appidTable = 0x3, dimstyleTable = 0x4
        static let styleTable = 0x5, ucsTable = 0x6, viewTable = 0x7, vportTable = 0x8, blockRecordTable = 0x9
        static let rootDictionary = 0xA, groupDictionary = 0xB, layoutDictionary = 0xC
        static let mlineStyleDictionary = 0xD, mlineStyleStandard = 0xE, plotSettingsDictionary = 0xF
        static let plotStyleDictionary = 0x10, plotStyleNormal = 0x11
        static let vportActive = 0x20, linetypeByBlock = 0x21, linetypeByLayer = 0x22, linetypeContinuous = 0x23
        static let layerZero = 0x24, styleStandard = 0x25, appidAcad = 0x26, dimstyleStandard = 0x27
        static let modelSpaceRecord = 0x28, paperSpaceRecord = 0x29
        static let modelSpaceBlock = 0x2A, modelSpaceEnd = 0x2B, paperSpaceBlock = 0x2C, paperSpaceEnd = 0x2D
        static let modelLayout = 0x2E, paperLayout = 0x2F
        static let firstFree = 0x100
    }

    private var out: [String] = []
    private var nextHandle = Handle.firstFree

    init(polylines: [DXFPolyline], circles: [DXFCircle]) {
        self.polylines = polylines
        self.circles = circles
    }

    func document() -> String {
        var writer = self
        return writer.write()
    }

    // MARK: - Document

    private mutating func write() -> String {
        // layers and linetypes for every style in use, in order of first use
        var styles: [DXFStyle] = []
        var seen = Set<DXFStyle>()
        for style in polylines.map(\.style) + circles.map(\.style) where seen.insert(style).inserted {
            styles.append(style)
        }
        var linetypes: [Linetype] = []
        var layers: [DXFStyle: Layer] = [:]
        var layerOrder: [Layer] = []
        var usedNames = Set<String>()
        for style in styles {
            var linetypeName = "Continuous"
            if style.isDashed {
                linetypeName = "DASH_" + style.dash.map(Self.nameComponent).joined(separator: "_")
                if !linetypes.contains(where: { $0.name == linetypeName }) {
                    linetypes.append(Linetype(name: linetypeName, pattern: style.dash))
                }
            }
            var name = Self.colorName(style.color) + (style.isDashed ? "-dash-" + style.dash.map(Self.nameComponent).joined(separator: "-") : "")
            while !usedNames.insert(name).inserted {
                name += "+"
            }
            let layer = Layer(name: name, aci: Self.nearestACI(style.color), linetype: linetypeName)
            layers[style] = layer
            layerOrder.append(layer)
        }

        let (minimum, maximum) = extents()

        beginSection("HEADER")
            variable("$ACADVER", (1, "AC1015"))
            variable("$DWGCODEPAGE", (3, "ANSI_1252"))
            variable("$INSBASE", (10, "0.0"), (20, "0.0"), (30, "0.0"))
            variable("$EXTMIN", (10, number(minimum.x)), (20, number(minimum.y)), (30, "0.0"))
            variable("$EXTMAX", (10, number(maximum.x)), (20, number(maximum.y)), (30, "0.0"))
            variable("$LTSCALE", (40, "1.0"))
            variable("$INSUNITS", (70, "4")) // millimeters
            variable("$MEASUREMENT", (70, "1")) // metric
            // $HANDSEED is filled in at the end, when all handles are known
            variable("$HANDSEED", (5, "HANDSEED"))
        endSection()
        beginSection("CLASSES")
        endSection()
        beginSection("TABLES")
            beginTable("VPORT", Handle.vportTable, count: 1)
                let center = CGPoint(x: (minimum.x + maximum.x) / 2, y: (minimum.y + maximum.y) / 2)
                let height = max(maximum.y - minimum.y, (maximum.x - minimum.x) / 1.5, 1) * 1.1
                record("VPORT", Handle.vportActive, owner: Handle.vportTable, "AcDbViewportTableRecord")
                group(2, "*Active"); group(70, "0")
                group(10, "0.0"); group(20, "0.0"); group(11, "1.0"); group(21, "1.0")
                group(12, number(center.x)); group(22, number(center.y))
                group(13, "0.0"); group(23, "0.0"); group(14, "0.5"); group(24, "0.5"); group(15, "0.5"); group(25, "0.5")
                group(16, "0.0"); group(26, "0.0"); group(36, "1.0"); group(17, "0.0"); group(27, "0.0"); group(37, "0.0")
                group(40, number(height)); group(41, "1.5"); group(42, "50.0"); group(43, "0.0"); group(44, "0.0")
                group(50, "0.0"); group(51, "0.0"); group(71, "0"); group(72, "1000"); group(73, "1"); group(74, "3")
                group(75, "0"); group(76, "0"); group(77, "0"); group(78, "0"); group(281, "0"); group(65, "0"); group(146, "0.0")
            endTable()
            beginTable("LTYPE", Handle.linetypeTable, count: 3 + linetypes.count)
                for (name, handle) in [("ByBlock", Handle.linetypeByBlock), ("ByLayer", Handle.linetypeByLayer), ("Continuous", Handle.linetypeContinuous)] {
                    record("LTYPE", handle, owner: Handle.linetypeTable, "AcDbLinetypeTableRecord")
                    group(2, name); group(70, "0"); group(3, name == "Continuous" ? "Solid line" : ""); group(72, "65"); group(73, "0"); group(40, "0.0")
                }
                for linetype in linetypes {
                    // an odd number of lengths repeats once, like CoreGraphics
                    let pattern = linetype.pattern.count.isMultiple(of: 2) ? linetype.pattern : linetype.pattern + linetype.pattern
                    record("LTYPE", allocateHandle(), owner: Handle.linetypeTable, "AcDbLinetypeTableRecord")
                    group(2, linetype.name); group(70, "0"); group(3, "Dashed " + linetype.pattern.map(Self.nameComponent).joined(separator: " "))
                    group(72, "65"); group(73, "\(pattern.count)"); group(40, number(pattern.reduce(0, +)))
                    for (index, length) in pattern.enumerated() {
                        group(49, number(index.isMultiple(of: 2) ? length : -length)); group(74, "0")
                    }
                }
            endTable()
            beginTable("LAYER", Handle.layerTable, count: 1 + layerOrder.count)
                record("LAYER", Handle.layerZero, owner: Handle.layerTable, "AcDbLayerTableRecord")
                group(2, "0"); group(70, "0"); group(62, "7"); group(6, "Continuous"); group(370, "-3"); group(390, hex(Handle.plotStyleNormal))
                for layer in layerOrder {
                    record("LAYER", allocateHandle(), owner: Handle.layerTable, "AcDbLayerTableRecord")
                    group(2, layer.name); group(70, "0"); group(62, "\(layer.aci)"); group(6, layer.linetype)
                    group(370, "-3"); group(390, hex(Handle.plotStyleNormal))
                }
            endTable()
            beginTable("STYLE", Handle.styleTable, count: 1)
                record("STYLE", Handle.styleStandard, owner: Handle.styleTable, "AcDbTextStyleTableRecord")
                group(2, "Standard"); group(70, "0"); group(40, "0.0"); group(41, "1.0"); group(50, "0.0"); group(71, "0")
                group(42, "2.5"); group(3, "txt"); group(4, "")
            endTable()
            beginTable("VIEW", Handle.viewTable, count: 0)
            endTable()
            beginTable("UCS", Handle.ucsTable, count: 0)
            endTable()
            beginTable("APPID", Handle.appidTable, count: 1)
                record("APPID", Handle.appidAcad, owner: Handle.appidTable, "AcDbRegAppTableRecord")
                group(2, "ACAD"); group(70, "0")
            endTable()
            beginTable("DIMSTYLE", Handle.dimstyleTable, count: 1, subclass: "AcDbDimStyleTable")
                group(0, "DIMSTYLE"); group(105, hex(Handle.dimstyleStandard)); group(330, hex(Handle.dimstyleTable))
                group(100, "AcDbSymbolTableRecord"); group(100, "AcDbDimStyleTableRecord")
                group(2, "Standard"); group(70, "0"); group(3, ""); group(4, "")
                for (code, value) in Self.standardDimstyle {
                    group(code, value)
                }
            endTable()
            beginTable("BLOCK_RECORD", Handle.blockRecordTable, count: 2)
                record("BLOCK_RECORD", Handle.modelSpaceRecord, owner: Handle.blockRecordTable, "AcDbBlockTableRecord")
                group(2, "*Model_Space"); group(340, hex(Handle.modelLayout))
                record("BLOCK_RECORD", Handle.paperSpaceRecord, owner: Handle.blockRecordTable, "AcDbBlockTableRecord")
                group(2, "*Paper_Space"); group(340, hex(Handle.paperLayout))
            endTable()
        endSection()
        beginSection("BLOCKS")
            for (name, record, begin, end) in [("*Model_Space", Handle.modelSpaceRecord, Handle.modelSpaceBlock, Handle.modelSpaceEnd),
                ("*Paper_Space", Handle.paperSpaceRecord, Handle.paperSpaceBlock, Handle.paperSpaceEnd)] {
                group(0, "BLOCK"); group(5, hex(begin)); group(330, hex(record)); group(100, "AcDbEntity"); group(8, "0")
                group(100, "AcDbBlockBegin"); group(2, name); group(70, "0"); group(10, "0.0"); group(20, "0.0"); group(30, "0.0")
                group(3, name); group(1, "")
                group(0, "ENDBLK"); group(5, hex(end)); group(330, hex(record)); group(100, "AcDbEntity"); group(8, "0")
                group(100, "AcDbBlockEnd")
            }
        endSection()
        beginSection("ENTITIES")
            for polyline in polylines {
                writePolyline(polyline, layer: layers[polyline.style]!.name)
            }
            for circle in circles {
                group(0, "CIRCLE"); group(5, hex(allocateHandle())); group(330, hex(Handle.modelSpaceRecord))
                group(100, "AcDbEntity"); group(8, layers[circle.style]!.name)
                group(100, "AcDbCircle"); group(10, number(circle.center.x)); group(20, number(circle.center.y)); group(30, "0.0")
                group(40, number(circle.radius))
            }
        endSection()
        beginSection("OBJECTS")
            dictionary(Handle.rootDictionary, owner: 0, entries: [
                ("ACAD_GROUP", Handle.groupDictionary),
                ("ACAD_LAYOUT", Handle.layoutDictionary),
                ("ACAD_MLINESTYLE", Handle.mlineStyleDictionary),
                ("ACAD_PLOTSETTINGS", Handle.plotSettingsDictionary),
                ("ACAD_PLOTSTYLENAME", Handle.plotStyleDictionary),
            ])
            dictionary(Handle.groupDictionary, owner: Handle.rootDictionary, entries: [])
            dictionary(Handle.layoutDictionary, owner: Handle.rootDictionary, entries: [("Model", Handle.modelLayout), ("Layout1", Handle.paperLayout)])
            dictionary(Handle.mlineStyleDictionary, owner: Handle.rootDictionary, entries: [("Standard", Handle.mlineStyleStandard)])
            dictionary(Handle.plotSettingsDictionary, owner: Handle.rootDictionary, entries: [])

            group(0, "ACDBDICTIONARYWDFLT"); group(5, hex(Handle.plotStyleDictionary)); group(330, hex(Handle.rootDictionary))
            group(100, "AcDbDictionary"); group(281, "1"); group(3, "Normal"); group(350, hex(Handle.plotStyleNormal))
            group(100, "AcDbDictionaryWithDefault"); group(340, hex(Handle.plotStyleNormal))
            group(0, "ACDBPLACEHOLDER"); group(5, hex(Handle.plotStyleNormal)); group(330, hex(Handle.plotStyleDictionary))

            group(0, "MLINESTYLE"); group(5, hex(Handle.mlineStyleStandard))
            group(102, "{ACAD_REACTORS"); group(330, hex(Handle.mlineStyleDictionary)); group(102, "}")
            group(330, hex(Handle.mlineStyleDictionary)); group(100, "AcDbMlineStyle"); group(2, "Standard"); group(70, "0"); group(3, "")
            group(62, "256"); group(51, "90.0"); group(52, "90.0"); group(71, "2")
            group(49, "0.5"); group(62, "256"); group(6, "BYLAYER"); group(49, "-0.5"); group(62, "256"); group(6, "BYLAYER")

            layout(Handle.modelLayout, name: "Model", tabOrder: 0, flags: 1024, blockRecord: Handle.modelSpaceRecord)
            layout(Handle.paperLayout, name: "Layout1", tabOrder: 1, flags: 0, blockRecord: Handle.paperSpaceRecord)
        endSection()
        group(0, "EOF")

        let handleSeed = hex(nextHandle)
        return out.joined(separator: "\n").replacingOccurrences(of: "\n  5\nHANDSEED\n", with: "\n  5\n\(handleSeed)\n") + "\n"
    }

    private mutating func writePolyline(_ polyline: DXFPolyline, layer: String) {
        // vertices: the start of every segment with its bulge, plus the end point of an open polyline
        var vertices: [(point: CGPoint, bulge: Double)] = polyline.segments.map { ($0.startPoint, $0.bulge) }
        if !polyline.closed, let last = polyline.segments.last {
            vertices.append((last.endPoint, 0))
        }
        vertices = Self.simplified(vertices, closed: polyline.closed)

        group(0, "LWPOLYLINE"); group(5, hex(allocateHandle())); group(330, hex(Handle.modelSpaceRecord))
        group(100, "AcDbEntity"); group(8, layer)
        group(100, "AcDbPolyline"); group(90, "\(vertices.count)"); group(70, polyline.closed ? "1" : "0"); group(43, "0.0")
        for vertex in vertices {
            group(10, number(vertex.point.x)); group(20, number(vertex.point.y))
            if vertex.bulge != 0 {
                group(42, number(vertex.bulge))
            }
        }
    }

    /// Drops vertices that lie on a straight line between their neighbors (in the same direction).
    private static func simplified(_ vertices: [(point: CGPoint, bulge: Double)], closed: Bool) -> [(point: CGPoint, bulge: Double)] {
        guard vertices.count > 2 else {
            return vertices
        }
        var result = [vertices[0]]
        for index in 1 ..< vertices.count - 1 {
            let previous = result[result.count - 1]
            let vertex = vertices[index]
            let next = vertices[index + 1].point
            if previous.bulge == 0, vertex.bulge == 0 {
                let a = CGPoint(x: vertex.point.x - previous.point.x, y: vertex.point.y - previous.point.y)
                let b = CGPoint(x: next.x - vertex.point.x, y: next.y - vertex.point.y)
                let cross = a.x * b.y - a.y * b.x
                let dot = a.x * b.x + a.y * b.y
                if abs(cross) <= 1e-9 * hypot(a.x, a.y) * hypot(b.x, b.y), dot > 0 {
                    continue
                }
            }
            result.append(vertex)
        }
        result.append(vertices[vertices.count - 1])
        return result
    }

    // MARK: - Building blocks

    private mutating func group(_ code: Int, _ value: String) {
        out.append(String(repeating: " ", count: max(0, 3 - String(code).count)) + "\(code)")
        out.append(value)
    }

    private mutating func beginSection(_ name: String) {
        group(0, "SECTION")
        group(2, name)
    }

    private mutating func endSection() {
        group(0, "ENDSEC")
    }

    private mutating func variable(_ name: String, _ values: (Int, String)...) {
        group(9, name)
        for (code, value) in values {
            group(code, value)
        }
    }

    private mutating func beginTable(_ name: String, _ handle: Int, count: Int, subclass: String? = nil) {
        group(0, "TABLE"); group(2, name); group(5, hex(handle)); group(330, "0")
        group(100, "AcDbSymbolTable"); group(70, "\(count)")
        if let subclass {
            group(100, subclass)
        }
    }

    private mutating func endTable() {
        group(0, "ENDTAB")
    }

    private mutating func record(_ type: String, _ handle: Int, owner: Int, _ subclass: String) {
        group(0, type); group(5, hex(handle)); group(330, hex(owner))
        group(100, "AcDbSymbolTableRecord"); group(100, subclass)
    }

    private mutating func dictionary(_ handle: Int, owner: Int, entries: [(String, Int)]) {
        group(0, "DICTIONARY"); group(5, hex(handle)); group(330, hex(owner))
        group(100, "AcDbDictionary"); group(280, "0"); group(281, "1")
        for (name, entry) in entries {
            group(3, name); group(350, hex(entry))
        }
    }

    private mutating func layout(_ handle: Int, name: String, tabOrder: Int, flags: Int, blockRecord: Int) {
        group(0, "LAYOUT"); group(5, hex(handle)); group(330, hex(Handle.layoutDictionary))
        group(100, "AcDbPlotSettings"); group(1, ""); group(2, "none_device"); group(4, ""); group(6, "")
        for (code, value) in [(40, "7.5"), (41, "20.0"), (42, "7.5"), (43, "20.0"), (44, "420.0"), (45, "297.0"),
                              (46, "0.0"), (47, "0.0"), (48, "0.0"), (49, "0.0"), (140, "0.0"), (141, "0.0"),
                              (142, "1.0"), (143, "1.0")] {
            group(code, value)
        }
        group(70, "\(flags)"); group(72, "1"); group(73, "0"); group(74, "5"); group(7, ""); group(75, "16")
        group(76, "0"); group(77, "2"); group(78, "300"); group(147, "1.0"); group(148, "0.0"); group(149, "0.0")
        group(100, "AcDbLayout"); group(1, name); group(70, "1"); group(71, "\(tabOrder)")
        for (code, value) in [(10, "0.0"), (20, "0.0"), (11, "420.0"), (21, "297.0"), (12, "0.0"), (22, "0.0"), (32, "0.0"),
                              (14, "1e+20"), (24, "1e+20"), (34, "1e+20"), (15, "-1e+20"), (25, "-1e+20"), (35, "-1e+20"),
                              (146, "0.0"), (13, "0.0"), (23, "0.0"), (33, "0.0"), (16, "1.0"), (26, "0.0"), (36, "0.0"),
                              (17, "0.0"), (27, "1.0"), (37, "0.0"), (76, "1")] {
            group(code, value)
        }
        group(330, hex(blockRecord))
    }

    private mutating func allocateHandle() -> Int {
        defer { nextHandle += 1 }
        return nextHandle
    }

    private func hex(_ handle: Int) -> String {
        String(handle, radix: 16, uppercase: true)
    }

    private func number(_ value: Double) -> String {
        DecimalFormatting.dxf(value)
    }

    private func extents() -> (CGPoint, CGPoint) {
        var minimum = CGPoint(x: CGFloat.infinity, y: .infinity)
        var maximum = CGPoint(x: -CGFloat.infinity, y: -.infinity)
        func include(_ point: CGPoint) {
            minimum = CGPoint(x: min(minimum.x, point.x), y: min(minimum.y, point.y))
            maximum = CGPoint(x: max(maximum.x, point.x), y: max(maximum.y, point.y))
        }
        for polyline in polylines {
            for segment in polyline.segments {
                segment.points().forEach(include)
            }
        }
        for circle in circles {
            include(CGPoint(x: circle.center.x - circle.radius, y: circle.center.y - circle.radius))
            include(CGPoint(x: circle.center.x + circle.radius, y: circle.center.y + circle.radius))
        }
        if minimum.x > maximum.x {
            return (.zero, .zero)
        }
        return (minimum, maximum)
    }

    // MARK: - Names and colors

    private static func nameComponent(_ value: Double) -> String {
        DecimalFormatting.dxf(value)
            .replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: ".", with: "p")
    }

    private static let colorNames: [(CanvasColor, String)] = [
        (.black, "black"), (.white, "white"), (.yellow, "yellow"), (.cyan, "cyan"), (.red, "red"), (.green, "green"),
        (.blue, "blue"), (.orange, "orange"), (.pink, "pink"), (.indigo, "indigo"), (.gray, "gray"), (.purple, "purple"),
        (.mint, "mint"),
    ]

    private static func colorName(_ color: CanvasColor) -> String {
        let opaque = CanvasColor(color.r, color.g, color.b, 1)
        if let name = colorNames.first(where: { $0.0 == opaque })?.1 {
            return name
        }
        func byte(_ value: Double) -> String {
            let hex = String(Int((min(max(value, 0), 1) * 255).rounded()), radix: 16, uppercase: true)
            return hex.count == 1 ? "0" + hex : hex
        }
        return "rgb-" + byte(color.r) + byte(color.g) + byte(color.b)
    }

    /// The nearest AutoCAD Color Index (1...255). Black maps to 7, which shows black on a white background.
    static func nearestACI(_ color: CanvasColor) -> Int {
        let r = color.r * 255, g = color.g * 255, b = color.b * 255
        var best = 7
        var bestDistance = Double.infinity
        for index in 1 ... 255 {
            let rgb = aciColors[index]
            var distance = pow(Double((rgb >> 16) & 0xFF) - r, 2) + pow(Double((rgb >> 8) & 0xFF) - g, 2) + pow(Double(rgb & 0xFF) - b, 2)
            if index == 7 {
                // ACI 7 is white or black depending on the background: treat it as both
                distance = min(distance, r * r + g * g + b * b)
            }
            if distance < bestDistance {
                bestDistance = distance
                best = index
            }
        }
        return best
    }

    /// The RGB values of the AutoCAD Color Index, 0...255.
    static let aciColors: [Int] = [
        0x000000, 0xFF0000, 0xFFFF00, 0x00FF00, 0x00FFFF, 0x0000FF, 0xFF00FF, 0xFFFFFF,
        0x808080, 0xC0C0C0, 0xFF0000, 0xFF7F7F, 0xA50000, 0xA55252, 0x7F0000, 0x7F3F3F,
        0x4C0000, 0x4C2626, 0x260000, 0x261313, 0xFF3F00, 0xFF9F7F, 0xA52900, 0xA56752,
        0x7F1F00, 0x7F4F3F, 0x4C1300, 0x4C2F26, 0x260900, 0x261713, 0xFF7F00, 0xFFBF7F,
        0xA55200, 0xA57C52, 0x7F3F00, 0x7F5F3F, 0x4C2600, 0x4C3926, 0x261300, 0x261C13,
        0xFFBF00, 0xFFDF7F, 0xA57C00, 0xA59152, 0x7F5F00, 0x7F6F3F, 0x4C3900, 0x4C4226,
        0x261C00, 0x262113, 0xFFFF00, 0xFFFF7F, 0xA5A500, 0xA5A552, 0x7F7F00, 0x7F7F3F,
        0x4C4C00, 0x4C4C26, 0x262600, 0x262613, 0xBFFF00, 0xDFFF7F, 0x7CA500, 0x91A552,
        0x5F7F00, 0x6F7F3F, 0x394C00, 0x424C26, 0x1C2600, 0x212613, 0x7FFF00, 0xBFFF7F,
        0x52A500, 0x7CA552, 0x3F7F00, 0x5F7F3F, 0x264C00, 0x394C26, 0x132600, 0x1C2613,
        0x3FFF00, 0x9FFF7F, 0x29A500, 0x67A552, 0x1F7F00, 0x4F7F3F, 0x134C00, 0x2F4C26,
        0x092600, 0x172613, 0x00FF00, 0x7FFF7F, 0x00A500, 0x52A552, 0x007F00, 0x3F7F3F,
        0x004C00, 0x264C26, 0x002600, 0x132613, 0x00FF3F, 0x7FFF9F, 0x00A529, 0x52A567,
        0x007F1F, 0x3F7F4F, 0x004C13, 0x264C2F, 0x002609, 0x135817, 0x00FF7F, 0x7FFFBF,
        0x00A552, 0x52A57C, 0x007F3F, 0x3F7F5F, 0x004C26, 0x264C39, 0x002613, 0x13581C,
        0x00FFBF, 0x7FFFDF, 0x00A57C, 0x52A591, 0x007F5F, 0x3F7F6F, 0x004C39, 0x264C42,
        0x00261C, 0x135858, 0x00FFFF, 0x7FFFFF, 0x00A5A5, 0x52A5A5, 0x007F7F, 0x3F7F7F,
        0x004C4C, 0x264C4C, 0x002626, 0x135858, 0x00BFFF, 0x7FDFFF, 0x007CA5, 0x5291A5,
        0x005F7F, 0x3F6F7F, 0x00394C, 0x26427E, 0x001C26, 0x135858, 0x007FFF, 0x7FBFFF,
        0x0052A5, 0x527CA5, 0x003F7F, 0x3F5F7F, 0x00264C, 0x26397E, 0x001326, 0x131C58,
        0x003FFF, 0x7F9FFF, 0x0029A5, 0x5267A5, 0x001F7F, 0x3F4F7F, 0x00134C, 0x262F7E,
        0x000926, 0x131758, 0x0000FF, 0x7F7FFF, 0x0000A5, 0x5252A5, 0x00007F, 0x3F3F7F,
        0x00004C, 0x26267E, 0x000026, 0x131358, 0x3F00FF, 0x9F7FFF, 0x2900A5, 0x6752A5,
        0x1F007F, 0x4F3F7F, 0x13004C, 0x2F267E, 0x090026, 0x171358, 0x7F00FF, 0xBF7FFF,
        0x5200A5, 0x7C52A5, 0x3F007F, 0x5F3F7F, 0x26004C, 0x39267E, 0x130026, 0x1C1358,
        0xBF00FF, 0xDF7FFF, 0x7C00A5, 0x9152A5, 0x5F007F, 0x6F3F7F, 0x39004C, 0x42264C,
        0x1C0026, 0x581358, 0xFF00FF, 0xFF7FFF, 0xA500A5, 0xA552A5, 0x7F007F, 0x7F3F7F,
        0x4C004C, 0x4C264C, 0x260026, 0x581358, 0xFF00BF, 0xFF7FDF, 0xA5007C, 0xA55291,
        0x7F005F, 0x7F3F6F, 0x4C0039, 0x4C2642, 0x26001C, 0x581358, 0xFF007F, 0xFF7FBF,
        0xA50052, 0xA5527C, 0x7F003F, 0x7F3F5F, 0x4C0026, 0x4C2639, 0x260013, 0x58131C,
        0xFF003F, 0xFF7F9F, 0xA50029, 0xA55267, 0x7F001F, 0x7F3F4F, 0x4C0013, 0x4C262F,
        0x260009, 0x581317, 0x000000, 0x656565, 0x666666, 0x999999, 0xCCCCCC, 0xFFFFFF,
    ]

    private static let standardDimstyle: [(Int, String)] = [
        (40, "1.0"), (41, "2.5"), (42, "0.625"), (43, "3.75"), (44, "1.25"), (45, "0.0"), (46, "0.0"), (47, "0.0"),
        (48, "0.0"), (140, "2.5"), (141, "2.5"), (142, "0.0"), (143, "0.03937007874"), (144, "1.0"), (145, "0.0"),
        (146, "1.0"), (147, "0.625"), (148, "0.0"), (71, "0"), (72, "0"), (73, "0"), (74, "0"), (75, "0"), (76, "0"),
        (77, "1"), (78, "8"), (79, "3"), (170, "0"), (171, "3"), (172, "1"), (173, "0"), (174, "0"), (175, "0"),
        (176, "0"), (177, "0"), (178, "0"), (179, "2"), (271, "2"), (272, "2"), (273, "2"), (274, "3"), (275, "0"),
        (276, "0"), (277, "2"), (278, "44"), (279, "0"), (280, "0"), (281, "0"), (282, "0"), (283, "0"), (284, "8"),
        (285, "0"), (286, "0"), (288, "0"), (289, "3"), (371, "-2"), (372, "-2"),
    ]
}
