import AppKit
import Foundation

// All app colors use the sampler's SDR sRGB model. Alpha stays unassociated.
struct SampledColor: Equatable, Hashable, Codable, Sendable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    var alpha: Double = 1

    init(red: UInt8, green: UInt8, blue: UInt8, alpha: Double = 1) {
        self.red = red; self.green = green; self.blue = blue
        self.alpha = min(1, max(0, alpha.isFinite ? alpha : 1))
    }

    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard [3, 4, 6, 8].contains(value.count), value.allSatisfy({ $0.isASCII && $0.isHexDigit }) else { return nil }
        if value.count <= 4 { value = value.map { "\($0)\($0)" }.joined() }
        guard let bits = UInt32(value, radix: 16) else { return nil }
        let hasAlpha = value.count == 8
        let rgb = hasAlpha ? bits >> 8 : bits
        self.init(red: UInt8((rgb >> 16) & 255), green: UInt8((rgb >> 8) & 255), blue: UInt8(rgb & 255),
                  alpha: hasAlpha ? Double(bits & 255) / 255 : 1)
    }

    var hex: String { String(format: "#%02X%02X%02X", red, green, blue) }
    var hexAlpha: String { hex + String(format: "%02X", Int((alpha * 255).rounded())) }
    var identity: String { hexAlpha }
    var components: [Double] { [Double(red) / 255, Double(green) / 255, Double(blue) / 255] }
    var nsColor: NSColor { NSColor(srgbRed: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255, alpha: alpha) }
    static let white = SampledColor(red: 255, green: 255, blue: 255)
    static let black = SampledColor(red: 0, green: 0, blue: 0)

    static func linear(_ x: Double) -> Double { x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4) }
    static func encoded(_ x: Double) -> Double { x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055 }
    var luminance: Double {
        let c = components.map(Self.linear)
        return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
    }

    // Encoded sRGB source-over, matching ordinary CSS/AppKit compositing.
    func composited(over background: SampledColor) -> SampledColor {
        let a = alpha + background.alpha * (1 - alpha)
        guard a > 0 else { return SampledColor(red: 0, green: 0, blue: 0, alpha: 0) }
        let values = zip(components, background.components).map { ($0 * alpha + $1 * background.alpha * (1 - alpha)) / a }
        return Self.from(values, alpha: a)
    }

    static func from(_ values: [Double], alpha: Double = 1) -> SampledColor {
        let c = values.map { UInt8(min(255, max(0, ($0 * 255).rounded()))) }
        return SampledColor(red: c[0], green: c[1], blue: c[2], alpha: alpha)
    }

    // Bjorn Ottosson's published linear-sRGB <-> OKLab transforms.
    var lab: [Double] {
        let c = components.map(Self.linear), r = c[0], g = c[1], b = c[2]
        let l = cbrt(0.4122214708*r + 0.5363325363*g + 0.0514459929*b)
        let m = cbrt(0.2119034982*r + 0.6806995451*g + 0.1073969566*b)
        let s = cbrt(0.0883024619*r + 0.2817188376*g + 0.6299787005*b)
        return [0.2104542553*l + 0.793617785*m - 0.0040720468*s,
                1.9779984951*l - 2.428592205*m + 0.4505937099*s,
                0.0259040371*l + 0.7827717662*m - 0.808675766*s]
    }

    static func fromLab(_ lab: [Double], alpha: Double = 1) -> SampledColor {
        let l = pow(lab[0] + 0.3963377774*lab[1] + 0.2158037573*lab[2], 3)
        let m = pow(lab[0] - 0.1055613458*lab[1] - 0.0638541728*lab[2], 3)
        let s = pow(lab[0] - 0.0894841775*lab[1] - 1.291485548*lab[2], 3)
        return from([4.0767416621*l - 3.3077115913*m + 0.2309699292*s,
                     -1.2684380046*l + 2.6097574011*m - 0.3413193965*s,
                     -0.0041960863*l - 0.7034186147*m + 1.707614701*s].map(encoded), alpha: alpha)
    }

    var hslHSV: (h: Double, s: Double, l: Double, v: Double, sv: Double) {
        let c = components, r = c[0], g = c[1], b = c[2]
        let hi = c.max()!, lo = c.min()!, delta = hi - lo, light = (hi + lo) / 2
        var hue = 0.0
        if delta > 0 {
            if hi == r { hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
            else if hi == g { hue = (b - r) / delta + 2 }
            else { hue = (r - g) / delta + 4 }
            hue = (hue * 60 + 360).truncatingRemainder(dividingBy: 360)
        }
        return (hue, delta == 0 ? 0 : delta / (1 - abs(2 * light - 1)), light, hi, hi == 0 ? 0 : delta / hi)
    }
}

enum CopyFormat: String, Codable, CaseIterable, Identifiable {
    case hex, hexAlpha, rgb, rgba, hsl, hsla, hsv, hsb, oklch, displayP3, swiftUI, appKit, cssVariable, tailwind
    var id: String { rawValue }
    var title: String {
        switch self {
        case .hex: return "HEX"
        case .hexAlpha: return "HEX + alpha"
        case .rgb: return "RGB"
        case .rgba: return "RGBA"
        case .hsl: return "HSL"
        case .hsla: return "HSLA"
        case .hsv: return "HSV"
        case .hsb: return "HSB"
        case .oklch: return "OKLCH"
        case .displayP3: return "Display P3"
        case .swiftUI: return "SwiftUI Color"
        case .appKit: return "AppKit NSColor"
        case .cssVariable: return "CSS variable"
        case .tailwind: return "Tailwind value"
        }
    }

    func string(for color: SampledColor, name: String = "prismdrop") -> String {
        func n(_ x: Double, _ digits: Int = 4) -> String {
            let rounded = abs(x) < pow(10, -Double(digits)) / 2 ? 0 : x
            var value = String(format: "%.*f", locale: Locale(identifier: "en_US_POSIX"), digits, rounded)
            while value.contains(".") && value.hasSuffix("0") { value.removeLast() }
            if value.hasSuffix(".") { value.removeLast() }
            return value
        }
        let r = color.red, g = color.green, b = color.blue, a = n(color.alpha)
        let h = color.hslHSV
        let rgbValue = color.alpha < 1 ? "rgb(\(r) \(g) \(b) / \(a))" : "rgb(\(r) \(g) \(b))"
        switch self {
        case .hex: return color.hex
        case .hexAlpha: return color.hexAlpha
        case .rgb: return rgbValue
        case .rgba: return "rgba(\(r), \(g), \(b), \(a))"
        case .hsl: return "hsl(\(n(h.h, 2)) \(n(h.s * 100, 2))% \(n(h.l * 100, 2))%\(color.alpha < 1 ? " / \(a)" : ""))"
        case .hsla: return "hsla(\(n(h.h, 2)), \(n(h.s * 100, 2))%, \(n(h.l * 100, 2))%, \(a))"
        case .hsv, .hsb:
            return "\(rawValue)(\(n(h.h, 2))°, \(n(h.sv * 100, 2))%, \(n(h.v * 100, 2))%\(color.alpha < 1 ? ", \(a)" : ""))"
        case .oklch:
            let lab = color.lab, chroma = hypot(lab[1], lab[2])
            let hue = chroma < 0.00001 ? 0 : (atan2(lab[2], lab[1]) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
            return "oklch(\(n(lab[0] * 100, 3))% \(n(chroma, 5)) \(n(hue, 3))\(color.alpha < 1 ? " / \(a)" : ""))"
        case .displayP3:
            let p3 = color.nsColor.usingColorSpace(.displayP3)!
            return "color(display-p3 \(n(p3.redComponent)) \(n(p3.greenComponent)) \(n(p3.blueComponent))\(color.alpha < 1 ? " / \(a)" : ""))"
        case .swiftUI:
            let c = color.components
            return "Color(.sRGB, red: \(n(c[0])), green: \(n(c[1])), blue: \(n(c[2])), opacity: \(a))"
        case .appKit:
            let c = color.components
            return "NSColor(srgbRed: \(n(c[0])), green: \(n(c[1])), blue: \(n(c[2])), alpha: \(a))"
        case .cssVariable:
            let token = name.lowercased().unicodeScalars.map { CharacterSet.alphanumerics.contains($0) && $0.isASCII ? String($0) : "-" }.joined()
            return "--color-\(token.isEmpty ? "prismdrop" : token): \(color.alpha < 1 ? color.hexAlpha : color.hex);"
        case .tailwind: return rgbValue // Valid in Tailwind theme.colors and CSS @theme tokens.
        }
    }
}

struct ContrastResult {
    let foreground: SampledColor
    let background: SampledColor
    let ratio: Double
    init(foreground: SampledColor, background: SampledColor, canvas: SampledColor = .white) {
        self.foreground = foreground; self.background = background
        // Keep double precision through compositing: don't quantize translucent channels.
        let back = zip(background.components, canvas.components).map { $0 * background.alpha + $1 * (1 - background.alpha) }
        let front = zip(foreground.components, back).map { $0 * foreground.alpha + $1 * (1 - foreground.alpha) }
        func luminance(_ c: [Double]) -> Double {
            let l = c.map(SampledColor.linear)
            return 0.2126*l[0] + 0.7152*l[1] + 0.0722*l[2]
        }
        let l1 = luminance(front), l2 = luminance(back)
        ratio = (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }
    var normalAA: Bool { ratio >= 4.5 }
    var normalAAA: Bool { ratio >= 7 }
    var largeAA: Bool { ratio >= 3 }
    var largeAAA: Bool { ratio >= 4.5 }

    // Exact minimum Euclidean distance in 8-bit encoded sRGB at the current
    // alpha. For each R/G pair, luminance monotonicity gives two allowed B
    // intervals; only the B nearest the source can minimize RGB distance.
    // This searches the whole gamut in 65,536 pairs, not 16 million trials.
    func suggestion(target: Double = 4.5, canvas: SampledColor = .white) -> SampledColor? {
        guard ratio < target else { return nil }
        let back = zip(background.components, canvas.components).map { $0 * background.alpha + $1 * (1 - background.alpha) }
        let backL = 0.2126 * SampledColor.linear(back[0]) + 0.7152 * SampledColor.linear(back[1]) + 0.0722 * SampledColor.linear(back[2])
        let darkLimit = (backL + 0.05) / target - 0.05
        let lightLimit = target * (backL + 0.05) - 0.05
        let sourceR = Int(foreground.red), sourceG = Int(foreground.green), sourceB = Int(foreground.blue)
        for alpha in foreground.alpha < 1 ? [foreground.alpha, 1] : [1] {
            let tables = zip(back, [0.2126, 0.7152, 0.0722]).map { channel, coefficient in
                (0...255).map { coefficient * SampledColor.linear(Double($0) / 255 * alpha + channel * (1 - alpha)) }
            }
            var best: SampledColor?, bestDistance = Int.max
            for r in 0...255 {
                if Task.isCancelled { return nil }
                let dr = (r - sourceR) * (r - sourceR)
                if dr > bestDistance { continue }
                for g in 0...255 {
                    let rgDistance = dr + (g - sourceG) * (g - sourceG)
                    if rgDistance > bestDistance { continue }
                    let base = tables[0][r] + tables[1][g]
                    for dark in [true, false] {
                        if dark && base + tables[2][0] > darkLimit { continue }
                        if !dark && base + tables[2][255] < lightLimit { continue }
                        var low = 0, high = 255
                        while low < high {
                            let mid = dark ? (low + high + 1) / 2 : (low + high) / 2
                            let luminance = base + tables[2][mid]
                            if dark {
                                if luminance <= darkLimit { low = mid } else { high = mid - 1 }
                            } else {
                                if luminance >= lightLimit { high = mid } else { low = mid + 1 }
                            }
                        }
                        let nearestB = dark ? min(sourceB, low) : max(sourceB, low)
                        // Adjacent B handles floating-point equality at a boundary;
                        // final eligibility always uses the same contrast evaluator.
                        for b in [nearestB, nearestB + (dark ? -1 : 1)] where (0...255).contains(b) {
                            let distance = rgDistance + (b - sourceB) * (b - sourceB)
                            guard distance < bestDistance else { continue }
                            let candidate = SampledColor(red: UInt8(r), green: UInt8(g), blue: UInt8(b), alpha: alpha)
                            if ContrastResult(foreground: candidate, background: background, canvas: canvas).ratio >= target {
                                best = candidate; bestDistance = distance
                            }
                        }
                    }
                }
            }
            if let best { return best }
        }
        return nil
    }
}
