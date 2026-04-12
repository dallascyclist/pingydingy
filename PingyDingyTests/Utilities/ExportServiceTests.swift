import Testing
import Foundation
@testable import PingyDingy

@Test func exportFilenameFormatICMP() {
    let start = makeDate(2026, 4, 9, 13, 0)
    let end = makeDate(2026, 4, 9, 14, 0)
    let filename = ExportService.buildFilename(
        startDate: start, endDate: end,
        hostname: "router-1.lab", pingType: .icmp, port: 443, format: .csv
    )
    #expect(filename == "202604091300-202604091400_router-1.lab_icmp.csv")
}

@Test func exportFilenameFormatTCP() {
    let start = makeDate(2026, 4, 9, 13, 0)
    let end = makeDate(2026, 4, 9, 14, 0)
    let filename = ExportService.buildFilename(
        startDate: start, endDate: end,
        hostname: "web-prod-03", pingType: .tcp, port: 443, format: .json
    )
    #expect(filename == "202604091300-202604091400_web-prod-03_tcp443.json")
}

@Test func exportCSVContent() throws {
    let rows = [
        ExportRow(timestamp: makeDate(2026, 4, 9, 13, 0), rttMs: 12.4, success: true, resolvedIP: "10.0.1.1", networkInterface: nil, error: nil),
        ExportRow(timestamp: makeDate(2026, 4, 9, 13, 0, second: 1), rttMs: nil, success: false, resolvedIP: "10.0.1.1", networkInterface: nil, error: "timeout"),
    ]

    let url = try ExportService.export(rows: rows, hostname: "test", pingType: .icmp, port: 443, format: .csv)
    let content = try String(contentsOf: url, encoding: .utf8)

    #expect(content.contains("timestamp,rtt_ms,success,resolved_ip,interface,error"))
    #expect(content.contains("12.4,true,10.0.1.1,"))
    #expect(content.contains(",false,10.0.1.1,auto,timeout"))

    try? FileManager.default.removeItem(at: url)
}

@Test func exportJSONContent() throws {
    let rows = [
        ExportRow(timestamp: makeDate(2026, 4, 9, 13, 0), rttMs: 12.4, success: true, resolvedIP: "10.0.1.1", networkInterface: nil, error: nil),
    ]

    let url = try ExportService.export(rows: rows, hostname: "test", pingType: .tcp, port: 80, format: .json)
    let content = try String(contentsOf: url, encoding: .utf8)

    #expect(content.contains("\"rtt_ms\""))
    #expect(content.contains("\"success\" : true"))

    try? FileManager.default.removeItem(at: url)
}

@Test func exportEmptyRowsThrows() {
    #expect(throws: ExportError.self) {
        try ExportService.export(rows: [], hostname: "test", pingType: .icmp, port: 443, format: .csv)
    }
}

private func makeDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, second: Int = 0) -> Date {
    var c = DateComponents()
    c.year = year; c.month = month; c.day = day; c.hour = hour; c.minute = minute; c.second = second
    c.timeZone = TimeZone.current
    return Calendar.current.date(from: c)!
}
