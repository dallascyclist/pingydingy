import Foundation

struct PingResponse: Sendable {
    let rttMs: Double
    let resolvedIP: String
}

enum PingError: Error, LocalizedError {
    case timeout
    case connectionRefused
    case networkUnreachable
    case dnsResolutionFailed
    case cancelled
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .timeout: "timeout"
        case .connectionRefused: "connection refused"
        case .networkUnreachable: "network unreachable"
        case .dnsResolutionFailed: "DNS resolution failed"
        case .cancelled: "cancelled"
        case .unknown(let msg): msg
        }
    }
}

protocol PingTransport: Sendable {
    func ping(host: String, port: Int?) async throws -> PingResponse
    func cancel()
}
