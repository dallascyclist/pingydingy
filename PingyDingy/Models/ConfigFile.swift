import Foundation

struct ConfigHost: Codable, Sendable {
    let hostname: String
    let description: String?
    let pingType: PingType
    let port: Int
    let intervalSeconds: Int
    let loggingEnabled: Bool
    let perPingSoundEnabled: Bool
    let transitionSoundEnabled: Bool
    let networkInterface: String?

    var conflictKey: String {
        "\(hostname)|\(pingType.rawValue)|\(port)"
    }
}

struct ConfigFile: Codable, Sendable {
    let version: Int
    let exportedAt: Date
    let hosts: [ConfigHost]

    init(hosts: [ConfigHost]) {
        self.version = 1
        self.exportedAt = Date()
        self.hosts = hosts
    }

    static func fromHostConfigurations(_ configs: [HostConfiguration]) -> ConfigFile {
        let hosts = configs.map { config in
            ConfigHost(
                hostname: config.hostname,
                description: config.hostDescription,
                pingType: config.pingType,
                port: config.port,
                intervalSeconds: config.intervalSeconds,
                loggingEnabled: config.loggingEnabled,
                perPingSoundEnabled: config.perPingSoundEnabled,
                transitionSoundEnabled: config.transitionSoundEnabled,
                networkInterface: config.networkInterface
            )
        }
        return ConfigFile(hosts: hosts)
    }

    func toData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func fromData(_ data: Data) throws -> ConfigFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ConfigFile.self, from: data)
    }

    static func fromURL(_ url: URL) throws -> ConfigFile {
        let data = try Data(contentsOf: url)
        return try fromData(data)
    }

    func writeToTempFile() throws -> URL {
        let data = try toData()
        let formatter = ISO8601DateFormatter()
        let filename = "PingyDingy-Config-\(formatter.string(from: exportedAt)).pingydingy"
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }
}

enum ImportMode: String, CaseIterable {
    case merge = "Merge"
    case replace = "Replace"
}

enum ConflictResolution {
    case keepYours
    case useTheirs
}

struct ImportConflict: Identifiable {
    let id = UUID()
    let existingHost: HostConfiguration
    let incomingHost: ConfigHost
    var resolution: ConflictResolution = .keepYours
}

struct ImportPreview {
    let newHosts: [ConfigHost]
    var conflicts: [ImportConflict]
    var mode: ImportMode = .merge

    var totalToImport: Int {
        switch mode {
        case .merge:
            return newHosts.count + conflicts.filter { $0.resolution == .useTheirs }.count
        case .replace:
            return newHosts.count + conflicts.count
        }
    }
}
