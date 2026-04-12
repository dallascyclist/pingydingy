import Testing
import Foundation
@testable import PingyDingy

final class MockPingTransport: PingTransport, @unchecked Sendable {
    var responses: [Result<PingResponse, Error>] = []
    private var callIndex = 0
    private let lock = NSLock()

    func ping(host: String, port: Int?) async throws -> PingResponse {
        let index = lock.withLock {
            let i = callIndex
            callIndex += 1
            return i
        }

        guard index < responses.count else {
            return PingResponse(rttMs: 10, resolvedIP: host)
        }
        return try responses[index].get()
    }

    func cancel() {}
}

@MainActor
@Test func hostMonitorInitialState() {
    let config = HostConfiguration(hostname: "10.0.1.1")
    let transport = MockPingTransport()
    let soundManager = SoundManager()
    let monitor = HostMonitor(config: config, transport: transport, soundManager: soundManager)

    #expect(monitor.isRunning == false)
    #expect(monitor.isUp == false)
    #expect(monitor.sentCount == 0)
    #expect(monitor.receivedCount == 0)
    #expect(monitor.lostCount == 0)
    #expect(monitor.lastRTT == nil)
}

@MainActor
@Test func hostMonitorTracksSuccessfulPings() async throws {
    let config = HostConfiguration(hostname: "127.0.0.1", intervalSeconds: 1)
    let transport = MockPingTransport()
    transport.responses = [
        .success(PingResponse(rttMs: 12, resolvedIP: "127.0.0.1")),
        .success(PingResponse(rttMs: 14, resolvedIP: "127.0.0.1")),
    ]
    let soundManager = SoundManager()
    soundManager.masterSoundEnabled = false

    let monitor = HostMonitor(config: config, transport: transport, soundManager: soundManager)
    monitor.start()
    try await Task.sleep(for: .milliseconds(2500))
    monitor.stop()

    #expect(monitor.sentCount >= 2)
    #expect(monitor.receivedCount >= 2)
    #expect(monitor.lostCount == 0)
    #expect(monitor.isUp == true)
}

@MainActor
@Test func hostMonitorTracksFailedPings() async throws {
    let config = HostConfiguration(hostname: "127.0.0.1", intervalSeconds: 1)
    let transport = MockPingTransport()
    transport.responses = [
        .failure(PingError.timeout),
        .failure(PingError.timeout),
        .failure(PingError.timeout),
    ]
    let soundManager = SoundManager()
    soundManager.masterSoundEnabled = false

    let monitor = HostMonitor(config: config, transport: transport, soundManager: soundManager)
    monitor.start()
    try await Task.sleep(for: .milliseconds(1500))
    monitor.stop()

    #expect(monitor.sentCount >= 1)
    #expect(monitor.lostCount >= 1)
    #expect(monitor.isUp == false)
}

@MainActor
@Test func hostMonitorStopCancelsTask() async throws {
    let config = HostConfiguration(hostname: "127.0.0.1")
    let transport = MockPingTransport()
    let soundManager = SoundManager()
    let monitor = HostMonitor(config: config, transport: transport, soundManager: soundManager)

    monitor.start()
    #expect(monitor.isRunning == true)
    monitor.stop()
    #expect(monitor.isRunning == false)
}

@MainActor
@Test func hostMonitorDisplayLabel() {
    let soundManager = SoundManager()
    let transport = MockPingTransport()

    let config1 = HostConfiguration(hostname: "10.0.1.1", hostDescription: "Router")
    let m1 = HostMonitor(config: config1, transport: transport, soundManager: soundManager)
    #expect(m1.displayLabel == "Router")

    let config2 = HostConfiguration(hostname: "router.lab")
    let m2 = HostMonitor(config: config2, transport: transport, soundManager: soundManager)
    #expect(m2.displayLabel == "router.lab")

    let config3 = HostConfiguration(hostname: "10.0.1.1")
    let m3 = HostMonitor(config: config3, transport: transport, soundManager: soundManager)
    #expect(m3.displayLabel == nil)
}
