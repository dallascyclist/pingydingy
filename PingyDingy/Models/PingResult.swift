import Foundation
import SwiftData

// NOTE: #Index<PingResult>([\.hostId, \.timestamp]) requires iOS 18+ / macOS 15+.
// The compound index on (hostId, timestamp) should be added when the deployment
// target is raised, or applied via a ModelConfiguration/migration.
@Model
final class PingResult {
    var id: UUID
    var hostId: UUID
    var timestamp: Date
    var rttMs: Double?
    var success: Bool
    var resolvedIP: String
    var error: String?
    var networkInterface: String?

    init(
        hostId: UUID,
        rttMs: Double? = nil,
        success: Bool,
        resolvedIP: String,
        error: String? = nil,
        networkInterface: String? = nil
    ) {
        self.id = UUID()
        self.hostId = hostId
        self.timestamp = Date()
        self.rttMs = rttMs
        self.success = success
        self.resolvedIP = resolvedIP
        self.error = error
        self.networkInterface = networkInterface
    }
}
