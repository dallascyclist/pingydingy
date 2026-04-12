import Testing
import Foundation
@testable import PingyDingy

@Test func configFileRoundTrip() throws {
    let host = ConfigHost(
        hostname: "10.0.1.1", description: "Router", pingType: .icmp, port: 443,
        intervalSeconds: 5, loggingEnabled: true, perPingSoundEnabled: false, transitionSoundEnabled: true,
        networkInterface: nil
    )
    let config = ConfigFile(hosts: [host])
    let data = try config.toData()
    let decoded = try ConfigFile.fromData(data)

    #expect(decoded.version == 1)
    #expect(decoded.hosts.count == 1)
    #expect(decoded.hosts[0].hostname == "10.0.1.1")
    #expect(decoded.hosts[0].description == "Router")
    #expect(decoded.hosts[0].pingType == .icmp)
    #expect(decoded.hosts[0].intervalSeconds == 5)
    #expect(decoded.hosts[0].transitionSoundEnabled == true)
}

@Test func configFileWriteAndRead() throws {
    let host = ConfigHost(
        hostname: "example.com", description: nil, pingType: .tcp, port: 443,
        intervalSeconds: 1, loggingEnabled: true, perPingSoundEnabled: true, transitionSoundEnabled: false,
        networkInterface: nil
    )
    let config = ConfigFile(hosts: [host])
    let url = try config.writeToTempFile()
    let loaded = try ConfigFile.fromURL(url)

    #expect(loaded.hosts.count == 1)
    #expect(loaded.hosts[0].hostname == "example.com")
    #expect(loaded.hosts[0].pingType == .tcp)
    #expect(url.pathExtension == "pingydingy")

    try? FileManager.default.removeItem(at: url)
}

@Test func configHostConflictKey() {
    let a = ConfigHost(hostname: "router.lab", description: nil, pingType: .icmp, port: 443,
                       intervalSeconds: 1, loggingEnabled: true, perPingSoundEnabled: false, transitionSoundEnabled: false,
                       networkInterface: nil)
    let b = ConfigHost(hostname: "router.lab", description: "Different", pingType: .icmp, port: 443,
                       intervalSeconds: 5, loggingEnabled: false, perPingSoundEnabled: true, transitionSoundEnabled: true,
                       networkInterface: nil)
    let c = ConfigHost(hostname: "router.lab", description: nil, pingType: .tcp, port: 443,
                       intervalSeconds: 1, loggingEnabled: true, perPingSoundEnabled: false, transitionSoundEnabled: false,
                       networkInterface: nil)

    #expect(a.conflictKey == b.conflictKey)
    #expect(a.conflictKey != c.conflictKey)
}

@Test func configFileFromHostConfiguration() {
    let config = HostConfiguration(
        hostname: "8.8.8.8", hostDescription: "Google DNS", pingType: .icmp, port: 443,
        intervalSeconds: 10, loggingEnabled: true, perPingSoundEnabled: false, transitionSoundEnabled: true
    )
    let file = ConfigFile.fromHostConfigurations([config])

    #expect(file.version == 1)
    #expect(file.hosts.count == 1)
    #expect(file.hosts[0].hostname == "8.8.8.8")
    #expect(file.hosts[0].description == "Google DNS")
}
