import Testing
import Foundation
@testable import PingyDingy

@Test func icmpTransportPingsLocalhost() async throws {
    let transport = ICMPTransport()
    let response = try await transport.ping(host: "127.0.0.1", port: nil)
    #expect(response.rttMs >= 0)
    #expect(response.rttMs < 1000)
    #expect(response.resolvedIP == "127.0.0.1")
}

@Test func icmpTransportPingsPublicDNS() async throws {
    let transport = ICMPTransport()
    let response = try await transport.ping(host: "1.1.1.1", port: nil)
    #expect(response.rttMs > 0)
    #expect(response.rttMs < 5000)
    #expect(response.resolvedIP == "1.1.1.1")
}

@Test func icmpTransportResolvesHostname() async throws {
    let transport = ICMPTransport()
    let response = try await transport.ping(host: "one.one.one.one", port: nil)
    #expect(response.rttMs > 0)
    #expect(!response.resolvedIP.isEmpty)
    #expect(response.resolvedIP != "one.one.one.one")
}

@Test func icmpTransportCancel() async {
    let transport = ICMPTransport()
    let task = Task {
        try await transport.ping(host: "192.0.2.1", port: nil)
    }
    try? await Task.sleep(for: .milliseconds(100))
    transport.cancel()
    task.cancel()

    do {
        _ = try await task.value
        #expect(Bool(false), "Should have thrown")
    } catch {
        // Cancelled or timeout — both acceptable
    }
}
