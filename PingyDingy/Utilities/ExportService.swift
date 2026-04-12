import Foundation

enum ExportFormat: String, CaseIterable {
    case csv
    case json
}

struct ExportRow: Sendable {
    let timestamp: Date
    let rttMs: Double?
    let success: Bool
    let resolvedIP: String
    let networkInterface: String?
    let error: String?
}

enum ExportError: Error, LocalizedError {
    case noData
    var errorDescription: String? {
        switch self {
        case .noData: "No data to export"
        }
    }
}

struct ExportService {
    nonisolated(unsafe) private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let fileFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMddHHmm"
        f.timeZone = TimeZone.current
        return f
    }()

    static func export(
        rows: [ExportRow],
        hostname: String,
        pingType: PingType,
        port: Int,
        format: ExportFormat
    ) throws -> URL {
        guard !rows.isEmpty else { throw ExportError.noData }

        let sortedRows = rows.sorted { $0.timestamp < $1.timestamp }
        let startDate = sortedRows.first!.timestamp
        let endDate = sortedRows.last!.timestamp

        let filename = buildFilename(
            startDate: startDate, endDate: endDate,
            hostname: hostname, pingType: pingType, port: port, format: format
        )

        let content: String
        switch format {
        case .csv: content = generateCSV(rows: sortedRows)
        case .json: content = try generateJSON(rows: sortedRows)
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try content.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }

    static func buildFilename(
        startDate: Date, endDate: Date,
        hostname: String, pingType: PingType, port: Int,
        format: ExportFormat
    ) -> String {
        let start = fileFormatter.string(from: startDate)
        let end = fileFormatter.string(from: endDate)
        let sanitizedHost = hostname
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let proto = pingType == .tcp ? "tcp\(port)" : "icmp"
        return "\(start)-\(end)_\(sanitizedHost)_\(proto).\(format.rawValue)"
    }

    private static func generateCSV(rows: [ExportRow]) -> String {
        var lines = ["timestamp,rtt_ms,success,resolved_ip,interface,error"]
        for row in rows {
            let ts = isoFormatter.string(from: row.timestamp)
            let rtt = row.rttMs.map { String(format: "%.1f", $0) } ?? ""
            let success = row.success ? "true" : "false"
            let iface = row.networkInterface ?? "auto"
            let error = row.error ?? ""
            lines.append("\(ts),\(rtt),\(success),\(row.resolvedIP),\(iface),\(error)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func generateJSON(rows: [ExportRow]) throws -> String {
        let jsonRows = rows.map { row -> [String: Any] in
            var dict: [String: Any] = [
                "timestamp": isoFormatter.string(from: row.timestamp),
                "success": row.success,
                "resolved_ip": row.resolvedIP,
            ]
            if let rtt = row.rttMs { dict["rtt_ms"] = rtt }
            dict["interface"] = row.networkInterface ?? "auto"
            if let error = row.error { dict["error"] = error }
            return dict
        }
        let data = try JSONSerialization.data(
            withJSONObject: jsonRows,
            options: [.prettyPrinted, .sortedKeys]
        )
        return String(data: data, encoding: .utf8)!
    }
}
