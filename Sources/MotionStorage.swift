import Foundation

enum MotionStorageError: Error {
    case snapshotNotFound(URL)
}

enum MotionStorage {
    static func defaultWorkspaceURL(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        return base
            .appendingPathComponent("liquid-frames", isDirectory: true)
            .appendingPathComponent("motion-workspace.json", isDirectory: false)
    }

    static func save(
        snapshot: MotionWorkspaceSnapshot,
        to url: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        let targetURL = url ?? defaultWorkspaceURL(fileManager: fileManager)
        try ensureParentDirectoryExists(for: targetURL, fileManager: fileManager)
        let data = try encoder.encode(snapshot)
        try data.write(to: targetURL, options: [.atomic])
        return targetURL
    }

    static func load(
        from url: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> MotionWorkspaceSnapshot {
        let targetURL = url ?? defaultWorkspaceURL(fileManager: fileManager)
        guard fileManager.fileExists(atPath: targetURL.path) else {
            throw MotionStorageError.snapshotNotFound(targetURL)
        }
        let data = try Data(contentsOf: targetURL)
        return try decoder.decode(MotionWorkspaceSnapshot.self, from: data)
    }

    static func desktopExportURL(date: Date = Date(), fileManager: FileManager = .default) -> URL {
        let desktop = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        return desktop.appendingPathComponent(
            "liquid-frames-motion-\(Self.timestampFormatter.string(from: date)).json",
            isDirectory: false
        )
    }

    private static func ensureParentDirectoryExists(for url: URL, fileManager: FileManager) throws {
        let directory = url.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()
}
