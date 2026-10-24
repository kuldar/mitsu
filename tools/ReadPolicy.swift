import Foundation

enum ReadPolicy {
    static let adapter: Set<String> = ["ATAR", "ATI", "AT@1", "ATDP", "ATDPN", "ATRV", "ATCS", "ATE0", "ATL0", "ATS1", "ATH1", "ATD0", "ATCAF1", "ATCFC1", "ATAT1", "ATST64", "ATM0", "ATSP0", "ATSP6", "ATSH7DF"]
    static let pids: Set<Int> = [0, 0x20, 0x40, 0x60, 0x80, 0xA0, 0xC0, 0xE0, 1, 4, 5, 0x0C, 0x0D, 0x0F, 0x10, 0x11, 0x2F, 0x42, 0x5E]
    static let reads = Set(pids.map { String(format: "01%02X", $0) }).union(["0900", "0902", "0904", "0906", "090A", "03", "07", "0A"])
    // Published ETACS identity reads. This does not authorize live-data scans,
    // diagnostic-session changes, coding, actuator tests or arbitrary identifiers.
    static let bodyIdentity:Set<String>=["1A87","1A9C"]
    // OEM MUT3SE Data List records: column, headlamp duty, outputs, inputs.
    // One-shot applicability capture only; no automatic live body polling.
    static let bodyRecords:Set<String>=["2173","2178","217A","217E"]
    static let enhanced: [String: Set<String>] = ["7E1":["2102","2103"], "784":["2101"], "7B6":["2104"], "620":bodyIdentity.union(bodyRecords).union(["21B2"]), "688":bodyIdentity.union(["2134","2122","2123","2120","2121","2110","2111"])]
    static let routes: [String:String] = ["7E1":"7E9", "784":"785", "7B6":"7B7", "620":"504", "688":"511"]
    static let routeCommands: Set<String> = ["ATSH7E1", "ATSH784", "ATSH7B6", "ATFCSH7E1", "ATFCSH784", "ATFCSH7B6", "ATFCSD30080A", "ATFCSM1", "ATFCSM0", "ATCRA7E9", "ATCRA785", "ATCRA7B7", "ATCRA"]
    static func allowed(_ s: String, vehicle: Bool) -> Bool {
        adapter.contains(s) || (vehicle && (reads.contains(s) || routeCommands.contains(s) || ["ATSH620","ATFCSH620","ATCRA504","ATSH688","ATFCSH688","ATCRA511"].contains(s) || enhanced.values.contains(where: { $0.contains(s) })))
    }
    static func allowedOnHeader(_ s: String, header: String) -> Bool {
        if s.hasPrefix("21") || s.hasPrefix("1A") { return enhanced[header]?.contains(s) ?? false }
        if s.hasPrefix("ATFCSH") { return s == "ATFCSH" + header }
        if s.hasPrefix("ATCRA"), s != "ATCRA" { return s == "ATCRA" + (routes[header] ?? "") }
        return true
    }
}

/// Never assume the adapter's persisted configuration after reconnecting.
struct DiagnosticRouteState {
    private(set) var header = "unknown"
    private(set) var receiveFilter = "unknown"
    private(set) var flowHeader = "unknown"
    private(set) var flowData = "unknown"
    private(set) var flowMode = "unknown"
    private(set) var automaticFormatting = false
    private(set) var automaticFlowControl = false
    private(set) var protocolMode = "unknown"
    mutating func acknowledge(_ command: String) {
        if command == "ATCAF1" { automaticFormatting = true }
        else if command == "ATCFC1" { automaticFlowControl = true }
        else if command == "ATSP6" { protocolMode = "6" }
        else if command == "ATSP0" { protocolMode = "auto" }
        else if command.hasPrefix("ATSH") { header = String(command.dropFirst(4)) }
        else if command == "ATAR" || command == "ATCRA" { receiveFilter = "auto" }
        else if command.hasPrefix("ATCRA") { receiveFilter = String(command.dropFirst(5)) }
        else if command.hasPrefix("ATFCSH") { flowHeader = String(command.dropFirst(6)) }
        else if command.hasPrefix("ATFCSD") { flowData = String(command.dropFirst(6)) }
        else if command.hasPrefix("ATFCSM") { flowMode = String(command.dropFirst(6)) }
    }
    func canRead(_ command: String) -> Bool {
        guard automaticFormatting && automaticFlowControl else { return false }
        if command.hasPrefix("21") || command.hasPrefix("1A") {
            return protocolMode == "6" && ReadPolicy.enhanced[header]?.contains(command) == true &&
                receiveFilter == ReadPolicy.routes[header] && flowMode == "1" &&
                flowHeader == header && flowData == "30080A"
        }
        return (protocolMode == "6" || (protocolMode == "auto" && command == "0100")) &&
            ReadPolicy.reads.contains(command) && header == "7DF" &&
            receiveFilter == "auto" && flowMode == "0"
    }
}
