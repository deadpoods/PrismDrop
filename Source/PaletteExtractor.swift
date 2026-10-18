import Foundation
import CoreGraphics
import ImageIO

enum PaletteExtractor {
    enum ExtractionError: LocalizedError {
        case unreadable, noColors, tooLarge
        var errorDescription: String? {
            switch self {
            case .unreadable: return "This image couldn’t be decoded. Try a PNG, JPEG, or HEIC file."
            case .noColors: return "This image has no visible colors. Try an image with opaque content."
            case .tooLarge: return "Choose an image smaller than 100 MB."
            }
        }
    }

    static func extract(url: URL) throws -> [SampledColor] {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 100 * 1024 * 1024 else { throw ExtractionError.tooLarge }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { throw ExtractionError.unreadable }
        return try extract(source: source)
    }

    static func extract(data: Data) throws -> [SampledColor] {
        guard data.count <= 100 * 1024 * 1024 else { throw ExtractionError.tooLarge }
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { throw ExtractionError.unreadable }
        return try extract(source: source)
    }

    private static func extract(source: CGImageSource) throws -> [SampledColor] {
        try Task.checkCancellation()
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceThumbnailMaxPixelSize: 256,
                                        kCGImageSourceShouldCacheImmediately: true]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw ExtractionError.unreadable }
        return try quantize(image)
    }

    // Deterministic weighted OKLab k-means over a quantized histogram of every
    // thumbnail pixel. No random samples, and no full-resolution bitmap allocation.
    static func quantize(_ image: CGImage) throws -> [SampledColor] {
        guard image.width <= 256, image.height <= 256, image.width > 0, image.height > 0 else { throw ExtractionError.tooLarge }
        let count = image.width * image.height
        var pixels = [UInt8](repeating: 0, count: count * 4)
        guard let context = CGContext(data: &pixels, width: image.width, height: image.height, bitsPerComponent: 8,
                                      bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue) else { throw ExtractionError.unreadable }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        struct Bin { var r = 0.0; var g = 0.0; var b = 0.0; var a = 0.0; var count = 0.0 }
        var histogram: [Int: Bin] = [:]
        for index in 0..<count {
            let i = index * 4, a = Double(pixels[i + 3]) / 255
            guard a >= 0.1 else { continue }
            let r = min(255, Double(pixels[i]) / a), g = min(255, Double(pixels[i + 1]) / a), b = min(255, Double(pixels[i + 2]) / a)
            let key = (Int(r) >> 3) << 13 | (Int(g) >> 3) << 8 | (Int(b) >> 3) << 3 | (Int(pixels[i + 3]) >> 5)
            var bin = histogram[key] ?? Bin()
            bin.r += r; bin.g += g; bin.b += b; bin.a += a; bin.count += 1
            histogram[key] = bin
        }
        struct Point { let lab: [Double]; let weight: Double; let alpha: Double }
        let points = histogram.sorted { $0.key < $1.key }.map { _, bin -> Point in
            let color = SampledColor.from([bin.r, bin.g, bin.b].map { $0 / bin.count / 255 }, alpha: bin.a / bin.count)
            return Point(lab: color.lab, weight: bin.count * color.alpha, alpha: color.alpha)
        }
        guard !points.isEmpty else { throw ExtractionError.noColors }
        func distance(_ a: [Double], _ b: [Double]) -> Double { zip(a, b).reduce(0) { $0 + pow($1.0 - $1.1, 2) } }
        var centers = [points.max { $0.weight < $1.weight }!.lab]
        while centers.count < min(8, points.count) {
            let candidate = points.max { a, b in
                let da = centers.map { distance(a.lab, $0) }.min()!
                let db = centers.map { distance(b.lab, $0) }.min()!
                return da * sqrt(a.weight) < db * sqrt(b.weight)
            }!
            guard centers.map({ distance(candidate.lab, $0) }).min()! > 0.000001 else { break }
            centers.append(candidate.lab)
        }
        var weights = [Double](repeating: 0, count: centers.count)
        var alphas = weights
        for _ in 0..<24 {
            try Task.checkCancellation()
            var sums = centers.map { _ in [Double](repeating: 0, count: 3) }
            weights = centers.map { _ in 0 }; alphas = weights
            for p in points {
                let i = centers.indices.min { distance(p.lab, centers[$0]) < distance(p.lab, centers[$1]) }!
                for channel in 0..<3 { sums[i][channel] += p.lab[channel] * p.weight }
                weights[i] += p.weight; alphas[i] += p.alpha * p.weight
            }
            var movement = 0.0
            for i in centers.indices where weights[i] > 0 {
                let next = sums[i].map { $0 / weights[i] }
                movement += distance(next, centers[i]); centers[i] = next
            }
            if movement < 0.0000001 { break }
        }
        var result: [SampledColor] = []
        for i in centers.indices.sorted(by: { weights[$0] > weights[$1] }) where weights[i] > 0 {
            let color = SampledColor.fromLab(centers[i], alpha: alphas[i] / weights[i])
            if !result.contains(where: { distance($0.lab, color.lab) < 0.055 * 0.055 }) { result.append(color) }
        }
        return result
    }
}
