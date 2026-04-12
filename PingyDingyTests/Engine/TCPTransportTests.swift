import Testing
import Foundation
@testable import PingyDingy

@Test func tcpTransportConnectsToPublicHost() async throws {
    let transport = TCPTransport()
    let response = try await transport.ping(host: "1.1.1.1", port: 443)
    #expect(response.rttMs > 0)
    #expect(response.rttMs < 5000)
    #expect(!response.resolvedIP.isEmpty)
}

@Test func tcpTransportResolvesHostname() async throws {
    let transport = TCPTransport()
    let response = try await transport.ping(host: "one.one.one.one", port: 443)
    #expect(response.rttMs > 0)
    #expect(!response.resolvedIP.isEmpty)
}

@Test func tcpTransportConnectionRefused() async {
    let transport = TCPTransport()
    do {
        _ = try await transport.ping(host: "127.0.0.1", port: 1)
        #expect(Bool(false), "Should have thrown")
    } catch {
        // Any error is acceptable — connection refused or timeout
    }
}

@Test func tcpTransportCancel() async {
    let transport = TCPTransport()
    let task = Task {
        try await transport.ping(host: "192.0.2.1", port: 443)
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
