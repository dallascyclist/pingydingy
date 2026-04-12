import Foundation
import SwiftData

@Model
final class HostConfiguration {
    var id: UUID
    var hostname: String
    var hostDescription: String?
    var pingType: PingType
    var port: Int
    var intervalSeconds: Int
    var loggingEnabled: Bool
    var perPingSoundEnabled: Bool
    var transitionSoundEnabled: Bool
    var networkInterface: String?
    var sortOrder: Int
    var createdAt: Date

    init(
        hostname: String,
        hostDescription: String? = nil,
        pingType: PingType = .icmp,
        port: Int = 443,
        intervalSeconds: Int = 1,
        loggingEnabled: Bool = true,
        perPingSoundEnabled: Bool = false,
        transitionSoundEnabled: Bool = false,
        networkInterface: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.hostname = hostname
        self.hostDescription = hostDescription
        self.pingType = pingType
        self.port = port
        self.intervalSeconds = intervalSeconds
        self.loggingEnabled = loggingEnabled
        self.perPingSoundEnabled = perPingSoundEnabled
        self.transitionSoundEnabled = transitionSoundEnabled
        self.networkInterface = networkInterface
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}
