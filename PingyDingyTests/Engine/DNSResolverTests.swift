import Testing
import Foundation
@testable import PingyDingy

@Test func dnsResolverPassesThroughIPv4() throws {
    let resolver = DNSResolver()
    let result = try resolver.resolve(hostname: "10.0.1.1", previousIP: nil)
    #expect(result.ip == "10.0.1.1")
    #expect(result.isIPv6 == false)
    #expect(result.didChange == false)
}

@Test func dnsResolverPassesThroughIPv6() throws {
    let resolver = DNSResolver()
    let result = try resolver.resolve(hostname: "::1", previousIP: nil)
    #expect(result.ip == "::1")
    #expect(result.isIPv6 == true)
    #expect(result.didChange == false)
}

@Test func dnsResolverResolvesHostname() throws {
    let resolver = DNSResolver()
    let result = try resolver.resolve(hostname: "one.one.one.one", previousIP: nil)
    #expect(!result.ip.isEmpty)
    #expect(result.ip != "one.one.one.one")
    #expect(result.didChange == false)
}

@Test func dnsResolverDetectsChange() throws {
    let resolver = DNSResolver()
    let result = try resolver.resolve(hostname: "1.1.1.1", previousIP: "1.0.0.1")
    #expect(result.ip == "1.1.1.1")
    #expect(result.didChange == true)
}

@Test func dnsResolverNoChangeWhenSame() throws {
    let resolver = DNSResolver()
    let result = try resolver.resolve(hostname: "1.1.1.1", previousIP: "1.1.1.1")
    #expect(result.didChange == false)
}

@Test func dnsResolverThrowsOnBadHostname() {
    let resolver = DNSResolver()
    #expect(throws: PingError.self) {
        try resolver.resolve(hostname: "this.host.definitely.does.not.exist.invalid", previousIP: nil)
    }
}
