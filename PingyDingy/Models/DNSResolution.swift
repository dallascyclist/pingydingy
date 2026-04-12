import Foundation
import SwiftData

@Model
final class DNSResolution {
    var id: UUID
    var hostId: UUID
    var timestamp: Date
    var resolvedIP: String
    var previousIP: String?

    init(
        hostId: UUID,
        resolvedIP: String,
        previousIP: String? = nil
    ) {
        self.id = UUID()
        self.hostId = hostId
        self.timestamp = Date()
        self.resolvedIP = resolvedIP
        self.previousIP = previousIP
    }
}
