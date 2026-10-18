import Foundation

struct SavedColor: Codable, Identifiable, Equatable {
    var id = UUID()
    var color: SampledColor
    var name = ""
    var favorite = false
    var pickedAt = Date()
}

struct SavedPalette: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var colors: [SampledColor]
    var createdAt = Date()
}

struct ColorLibrary: Codable, Equatable {
    var version = 1
    var history: [SavedColor] = []
    var palettes: [SavedPalette] = []
    static let recentLimit = 100

    mutating func record(_ color: SampledColor, at date: Date = Date()) {
        if let index = history.firstIndex(where: { $0.color.identity == color.identity }) {
            var entry = history.remove(at: index)
            entry.color = color
            entry.pickedAt = date
            history.insert(entry, at: 0)
        } else {
            history.insert(SavedColor(color: color, pickedAt: date), at: 0)
        }
        trim()
    }

    mutating func trim() {
        var recentCount = 0
        history = history.filter {
            if $0.favorite { return true }
            recentCount += 1
            return recentCount <= Self.recentLimit
        }
    }

    mutating func clearHistory() { history.removeAll { !$0.favorite } }

    func encoded() throws -> Data { try JSONEncoder().encode(self) }

    static func load(from url: URL) throws -> ColorLibrary {
        guard FileManager.default.fileExists(atPath: url.path) else { return ColorLibrary() }
        let data = try Data(contentsOf: url)
        let library = try JSONDecoder().decode(ColorLibrary.self, from: data)
        guard library.version == 1 else { throw LibraryError.unsupportedVersion }
        let colors = library.history.map(\.color) + library.palettes.flatMap(\.colors)
        guard colors.allSatisfy({ $0.alpha.isFinite && (0...1).contains($0.alpha) }),
              Set(library.history.map(\.id)).count == library.history.count,
              Set(library.history.map { $0.color.identity }).count == library.history.count,
              Set(library.palettes.map(\.id)).count == library.palettes.count else { throw LibraryError.invalidData }
        var result = library
        result.history.sort { $0.pickedAt > $1.pickedAt }
        result.trim()
        return result
    }

    static func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    enum LibraryError: LocalizedError {
        case unsupportedVersion, invalidData
        var errorDescription: String? {
            switch self {
            case .unsupportedVersion: return "This library was made by a newer PrismDrop version."
            case .invalidData: return "The color library contains invalid or duplicate entries."
            }
        }
    }
}
