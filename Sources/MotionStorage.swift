import Foundation

enum MotionStorageError: Error {
    case snapshotNotFound(URL)
    case desktopExportNotFound(URL)
}

enum MotionStorage {
    static func defaultWorkspaceURL(fileManager: FileManager = .default) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
        return base
            .appendingPathComponent("liquid-frames", isDirectory: true)
            .appendingPathComponent("motion-workspace.json", isDirectory: false)
    }

    static func desktopDirectoryURL(fileManager: FileManager = .default) -> URL {
        fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
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

    static func save(
        text: String,
        to url: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        try ensureParentDirectoryExists(for: url, fileManager: fileManager)
        try Data(text.utf8).write(to: url, options: [.atomic])
        return url
    }

    static func desktopExportURL(date: Date = Date(), fileManager: FileManager = .default) -> URL {
        let desktop = desktopDirectoryURL(fileManager: fileManager)
        return desktop.appendingPathComponent(
            "liquid-frames-motion-\(Self.timestampFormatter.string(from: date)).json",
            isDirectory: false
        )
    }

    static func desktopReleaseGateURL(date: Date = Date(), fileManager: FileManager = .default) -> URL {
        let desktop = desktopDirectoryURL(fileManager: fileManager)
        return desktop.appendingPathComponent(
            "liquid-frames-release-gate-\(Self.timestampFormatter.string(from: date)).md",
            isDirectory: false
        )
    }

    static func latestDesktopExportURL(fileManager: FileManager = .default) -> URL? {
        let desktop = desktopDirectoryURL(fileManager: fileManager)
        guard let entries = try? fileManager.contentsOfDirectory(
            at: desktop,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return entries
            .filter { url in
                url.pathExtension.lowercased() == "json" &&
                    url.lastPathComponent.hasPrefix("liquid-frames-motion-")
            }
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
            .last
    }

    static func loadLatestDesktopExport(
        fileManager: FileManager = .default
    ) throws -> (url: URL, snapshot: MotionWorkspaceSnapshot) {
        let desktop = desktopDirectoryURL(fileManager: fileManager)
        guard let url = latestDesktopExportURL(fileManager: fileManager) else {
            throw MotionStorageError.desktopExportNotFound(desktop)
        }
        let snapshot = try load(from: url, fileManager: fileManager)
        return (url, snapshot)
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
