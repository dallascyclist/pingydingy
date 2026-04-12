import Testing
import Foundation
@testable import PingyDingy

@Test func hostConfigurationDefaults() {
    let host = HostConfiguration(hostname: "8.8.8.8")
    #expect(host.pingType == .icmp)
    #expect(host.port == 443)
    #expect(host.intervalSeconds == 1)
    #expect(host.loggingEnabled == true)
    #expect(host.perPingSoundEnabled == false)
    #expect(host.transitionSoundEnabled == false)
    #expect(host.networkInterface == nil)
}

@Test func hostConfigurationTCP() {
    let host = HostConfiguration(hostname: "example.com", pingType: .tcp, port: 80)
    #expect(host.pingType == .tcp)
    #expect(host.port == 80)
}

@Test func pingResultSuccess() {
    let result = PingResult(hostId: UUID(), rttMs: 12.5, success: true, resolvedIP: "10.0.1.1")
    #expect(result.rttMs == 12.5)
    #expect(result.success == true)
    #expect(result.error == nil)
}

@Test func pingResultFailure() {
    let result = PingResult(hostId: UUID(), success: false, resolvedIP: "10.0.1.1", error: "timeout")
    #expect(result.rttMs == nil)
    #expect(result.success == false)
    #expect(result.error == "timeout")
}

@Test func dnsResolutionTracksChange() {
    let resolution = DNSResolution(hostId: UUID(), resolvedIP: "52.1.2.3", previousIP: "52.1.2.1")
    #expect(resolution.resolvedIP == "52.1.2.3")
    #expect(resolution.previousIP == "52.1.2.1")
}

@Test func pingTypeEnum() {
    #expect(PingType.icmp.rawValue == "icmp")
    #expect(PingType.tcp.rawValue == "tcp")
    #expect(PingType.allCases.count == 2)
}
