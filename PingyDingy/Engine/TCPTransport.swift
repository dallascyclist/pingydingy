import Foundation
import Network

final class TCPTransport: PingTransport, @unchecked Sendable {
    private let timeoutSeconds: TimeInterval
    private var currentConnection: NWConnection?
    private let lock = NSLock()

    private let interfaceName: String?
    private let interfaceType: NWInterface.InterfaceType?

    init(interfaceName: String? = nil, interfaceType: NWInterface.InterfaceType? = nil, timeoutSeconds: TimeInterval = 10) {
        self.interfaceName = interfaceName
        self.interfaceType = interfaceType
        self.timeoutSeconds = timeoutSeconds
    }

    func ping(host: String, port: Int?) async throws -> PingResponse {
        let targetPort = NWEndpoint.Port(integerLiteral: UInt16(port ?? 443))
        let params = NWParameters.tcp
        if let ifType = interfaceType {
            params.requiredInterfaceType = ifType
        }
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: targetPort,
            using: params
        )

        lock.withLock { currentConnection = connection }

        let startTime = ContinuousClock.Instant.now

        return try await withCheckedThrowingContinuation { continuation in
            nonisolated(unsafe) var resumed = false
            let resumeOnce: @Sendable (Result<PingResponse, Error>) -> Void = { result in
                guard !resumed else { return }
                resumed = true
                continuation.resume(with: result)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let elapsed = ContinuousClock.Instant.now - startTime
                    let rttMs = Double(elapsed.components.attoseconds) / 1_000_000_000_000_000.0
                        + Double(elapsed.components.seconds) * 1000.0

                    let resolvedIP: String
                    if let endpoint = connection.currentPath?.remoteEndpoint,
                       case .hostPort(host: let remoteHost, port: _) = endpoint {
                        resolvedIP = "\(remoteHost)"
                    } else {
                        resolvedIP = host
                    }

                    connection.cancel()
                    resumeOnce(.success(PingResponse(rttMs: rttMs, resolvedIP: resolvedIP)))

                case .failed(let error):
                    connection.cancel()
                    let pingError = Self.mapError(error)
                    resumeOnce(.failure(pingError))

                case .cancelled:
                    resumeOnce(.failure(PingError.cancelled))

                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .userInitiated))

            DispatchQueue.global().asyncAfter(deadline: .now() + self.timeoutSeconds) {
                connection.cancel()
                resumeOnce(.failure(PingError.timeout))
            }
        }
    }

    func cancel() {
        lock.lock()
        let conn = currentConnection
        lock.unlock()
        conn?.cancel()
    }

    private static func mapError(_ error: NWError) -> PingError {
        switch error {
        case .posix(let code):
            switch code {
            case .ECONNREFUSED: return .connectionRefused
            case .ENETUNREACH, .EHOSTUNREACH: return .networkUnreachable
            default: return .unknown(error.localizedDescription)
            }
        case .dns(_):
            return .dnsResolutionFailed
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
