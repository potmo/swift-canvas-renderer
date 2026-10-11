import Foundation

/// Locale-independent number formatting for the DXF and SVG output.
///
/// The formatters used to be created per number with the user's current locale. That was slow (creating
/// the formatter dominated DXF export time) and broke the generated Python under e.g. Swedish locales,
/// which use U+2212 as the minus sign. These are created once, with a fixed locale and explicit symbols,
/// and produce the same text an English locale did.
enum DecimalFormatting {
    // NumberFormatter is thread-safe for formatting as long as it isn't mutated, which these never are
    // after creation.
    nonisolated(unsafe) private static var fixedFormatters: [Int: NumberFormatter] = [:]
    private static let fixedFormattersLock = NSLock()

    private static let decimalFormatter: NumberFormatter = {
        let formatter = makeFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.alwaysShowsDecimalSeparator = true
        formatter.hasThousandSeparators = false
        formatter.maximumFractionDigits = 8
        formatter.minimumFractionDigits = 1
        return formatter
    }()

    private static func makeFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.decimalSeparator = "."
        formatter.minusSign = "-"
        formatter.plusSign = "+"
        formatter.notANumberSymbol = "NaN"
        formatter.positiveInfinitySymbol = "+∞"
        formatter.negativeInfinitySymbol = "-∞"
        return formatter
    }

    private static func fixedFormatter(fractionDigits: Int) -> NumberFormatter {
        fixedFormattersLock.lock()
        defer { fixedFormattersLock.unlock() }
        if let formatter = fixedFormatters[fractionDigits] {
            return formatter
        }
        let formatter = makeFormatter()
        formatter.maximumFractionDigits = fractionDigits
        formatter.minimumFractionDigits = fractionDigits
        fixedFormatters[fractionDigits] = formatter
        return formatter
    }

    /// Exactly `fractionDigits` fraction digits, rounded half-to-even (the format `Double.toFixed` produces).
    static func fixed(_ value: Double, fractionDigits: Int) -> String {
        fixedFormatter(fractionDigits: fractionDigits).string(from: NSNumber(value: value)) ?? "NaN"
    }

    /// 1...8 fraction digits, always with a decimal point (SVG path data).
    static func decimal(_ value: Double) -> String {
        decimalFormatter.string(from: NSNumber(value: value))!
    }

    // Fixed point with up to 10 fraction digits and no exponent, for DXF group values.
    private static let dxfFormatter: NumberFormatter = {
        let formatter = makeFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.alwaysShowsDecimalSeparator = true
        formatter.hasThousandSeparators = false
        formatter.maximumFractionDigits = 10
        formatter.minimumFractionDigits = 1
        return formatter
    }()

    /// 1...10 fraction digits, always with a decimal point, never an exponent (DXF group values).
    static func dxf(_ value: Double) -> String {
        dxfFormatter.string(from: NSNumber(value: value))!
    }
}
