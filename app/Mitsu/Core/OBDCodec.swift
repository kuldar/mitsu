import Foundation

enum DiagnosticError: Error, LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case let .invalid(message) = self { return message }; return nil }
}

struct CANFrame: Equatable { let ecu: String; let payload: [UInt8] }

struct PromptBuffer {
    private var bytes = Data()
    private var completed = false
    mutating func feed(_ chunk: Data) throws -> String? {
        guard !completed, bytes.count + chunk.count <= 65_536 else { throw DiagnosticError.invalid("Unexpected or oversized adapter reply") }
        bytes.append(chunk)
        guard let end = bytes.firstIndex(of: 62) else { return nil }
        let tail = bytes.suffix(from: bytes.index(after: end))
        guard tail.allSatisfy({ [9,10,13,32].contains($0) }), let text = String(data: bytes.prefix(upTo: end), encoding: .ascii) else {
            throw DiagnosticError.invalid("Unsolicited bytes after adapter prompt")
        }
        completed = true
        return text
    }
}

enum OBDCodec {
    static func validatedSignalFrames(_ frames:[CANFrame],pid:UInt8,supported:[String:Set<UInt8>]) throws -> [CANFrame] {
        guard !frames.isEmpty else{throw DiagnosticError.invalid("No diagnostic signal replies")}
        var seen:[String:[UInt8]]=[:]
        for frame in frames{
            guard supported[frame.ecu]?.contains(pid) == true,seen[frame.ecu] == nil else{throw DiagnosticError.invalid("Unexpected or duplicate diagnostic responder")}
            _ = try decode(frame,pid:pid);seen[frame.ecu]=frame.payload
        }
        return frames.sorted{$0.ecu<$1.ecu}
    }
    static func withoutEcho(_ reply:String,command:String)->String {
        reply.components(separatedBy:.newlines).map{$0.trimmingCharacters(in:.whitespaces)}.filter{!$0.isEmpty && $0 != command}.joined(separator:"\r")
    }
    static func frames(_ text: String) throws -> [CANFrame] {
        var output: [CANFrame] = []
        var pending: [String: (length: Int, bytes: [UInt8], sequence: UInt8)] = [:]
        for line in text.components(separatedBy: .newlines) {
            let line = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line == "SEARCHING..." { continue }
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 3, parts.count <= 9, parts[0].count == 3,
                  let address = UInt16(parts[0], radix: 16), address <= 0x7FF else { throw DiagnosticError.invalid("Invalid CAN frame") }
            let ecu = parts[0].uppercased()
            let bytes = parts.dropFirst().compactMap { $0.count == 2 ? UInt8($0, radix:16) : nil }
            guard bytes.count == parts.count - 1 else { throw DiagnosticError.invalid("Invalid CAN bytes") }
            switch bytes[0] >> 4 {
            case 0:
                let length = Int(bytes[0] & 15)
                guard pending[ecu] == nil, (1...7).contains(length), bytes.count >= length + 1 else { throw DiagnosticError.invalid("Truncated or overlapping CAN frame") }
                output.append(CANFrame(ecu:ecu,payload:Array(bytes[1...length])))
            case 1:
                guard bytes.count == 8, pending[ecu] == nil else { throw DiagnosticError.invalid("Invalid first ISO-TP frame") }
                let length = Int(bytes[0] & 15)*256+Int(bytes[1])
                guard (8...4095).contains(length) else { throw DiagnosticError.invalid("Invalid ISO-TP length") }
                pending[ecu] = (length,Array(bytes.dropFirst(2)),1)
            case 2:
                guard var item = pending[ecu], bytes[0] & 15 == item.sequence else { throw DiagnosticError.invalid("Missing ISO-TP sequence") }
                let remaining=item.length-item.bytes.count
                guard bytes.count-1 >= min(7,remaining) else { throw DiagnosticError.invalid("Truncated ISO-TP continuation") }
                item.bytes += bytes.dropFirst()
                if item.bytes.count >= item.length {
                    output.append(CANFrame(ecu:ecu,payload:Array(item.bytes.prefix(item.length))))
                    pending.removeValue(forKey:ecu)
                } else { item.sequence = (item.sequence+1) & 15; pending[ecu] = item }
            default: throw DiagnosticError.invalid("Unexpected CAN frame type")
            }
        }
        guard pending.isEmpty, !output.isEmpty else { throw DiagnosticError.invalid("Incomplete diagnostic reply") }
        return output
    }
    static func decode(_ frame: CANFrame, pid: UInt8) throws -> Double {
        let lengths: [UInt8:Int] = [4:1,5:1,12:2,13:1,15:1,16:2,17:1,66:2]
        guard ["7E8","7E9"].contains(frame.ecu), let length = lengths[pid], frame.payload.count == length+2,
              frame.payload[0] == 0x41, frame.payload[1] == pid else { throw DiagnosticError.invalid("Mismatched signal response") }
        let a = Double(frame.payload[2]), n = frame.payload.dropFirst(2).reduce(0) { $0*256+Int($1) }
        switch pid {
        case 4,17: return a*100/255
        case 5,15: return a-40
        case 12: return Double(n)/4
        case 13: return a
        case 16: return Double(n)/100
        case 66: return Double(n)/1000
        default: throw DiagnosticError.invalid("Unsupported signal")
        }
    }
    static func supported(_ payload: [UInt8], base: Int) throws -> Set<UInt8> {
        guard payload.count == 4, base >= 0, base <= 224, base % 32 == 0 else { throw DiagnosticError.invalid("Invalid capability bitmap") }
        let bits = payload.reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
        return Set((1...32).compactMap { i in bits & (UInt32(1) << (32-i)) != 0 && base+i <= 255 ? UInt8(base+i) : nil })
    }
    static func steering(_ frame: CANFrame) throws -> Double {
        guard frame.ecu == "7B7", frame.payload.count >= 4, frame.payload.prefix(2) == [0x61,4] else { throw DiagnosticError.invalid("Invalid steering response") }
        let angle = (Double(Int(frame.payload[2])*256+Int(frame.payload[3]))-4096)/2
        guard abs(angle) <= 900 else { throw DiagnosticError.invalid("Steering value outside validated bounds") }
        return angle
    }
    static func dtcs(_ frame: CANFrame, service: UInt8) throws -> [String] {
        guard [3,7].contains(service), ["7E8","7E9"].contains(frame.ecu), frame.payload.first == service+0x40,
              frame.payload.count >= 2 else { throw DiagnosticError.invalid("Invalid emissions code response") }
        let data:[UInt8]
        if frame.payload.count % 2 == 0 {
            let count=Int(frame.payload[1]),rest=Array(frame.payload.dropFirst(2))
            guard rest.count >= count*2,rest.dropFirst(count*2).allSatisfy({$0==0}) else{throw DiagnosticError.invalid("Truncated emissions code list")}
            data=Array(rest.prefix(count*2))
        }else{data=Array(frame.payload.dropFirst())}
        var codes: [String] = []
        let systems=["P","C","B","U"]
        for i in stride(from:0,to:data.count,by:2) {
            let a = data[i], b=data[i+1]
            if a == 0 && b == 0 { continue }
            codes.append(systems[Int(a >> 6)] + String(format:"%01X%01X%02X", (a >> 4)&3, a&15,b))
        }
        return codes
    }
}
