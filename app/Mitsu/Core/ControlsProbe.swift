import Foundation

enum ControlsCaptureKind:String,Codable,CaseIterable {
    case climate,preferences
    var title:String{self == .climate ? "Climate":"Light & lock preferences"}
}
struct ControlsCaptureRequest {
    let kind:ControlsCaptureKind
    let observation:String
    init(kind:ControlsCaptureKind,observation:String){self.kind=kind;self.observation=String(observation.prefix(160))}
}
struct ControlsReadReply:Codable,Equatable {
    let request:String
    let responder:String
    let payloadHex:String
    static func decode(_ raw:String,request:String,responder:String,minimum:Int)throws->Self {
        let frames=try OBDCodec.frames(raw)
        guard frames.count==1,let frame=frames.first,frame.ecu==responder,
              (minimum...128).contains(frame.payload.count),
              frame.payload.prefix(2)==[request.hasPrefix("1A") ? UInt8(0x5A):0x61,UInt8(request.suffix(2),radix:16)!] else {
            throw DiagnosticError.invalid("Unexpected diagnostic reply")
        }
        return .init(request:request,responder:responder,payloadHex:frame.payload.map{String(format:"%02X",$0)}.joined())
    }
}
struct ControlsReport:Codable {
    var started:Date
    let kind:ControlsCaptureKind
    var observation:String
    var replies:[ControlsReadReply]=[]
    var attempts:[BodyIdentityReport.Attempt]=[]
    var outcome="No records read"
    var note="Unvalidated raw applicability capture. No settings changed or actuators operated. A customization snapshot is not a full ECU backup or a coding recovery file. Candidate climate version agreement does not validate exact hardware. No VIN requested."
    func persist(in folder:URL)throws->URL {
        let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys];encoder.dateEncodingStrategy = .iso8601
        let data=try encoder.encode(self)
        let archive=folder.appendingPathComponent("controls-capture-"+String(format:"%.3f",started.timeIntervalSince1970)+"-"+kind.rawValue)
        try FileManager.default.createDirectory(at:archive,withIntermediateDirectories:true)
        let name="Mitsu-"+kind.rawValue+".json"
        try data.write(to:archive.appendingPathComponent(name),options:.atomic)
        let latest=folder.appendingPathComponent(name)
        try data.write(to:latest,options:.atomic)
        return latest
    }
}

/// Read-only preparation. Diagnostic actuator templates never enter this type.
@MainActor enum ControlsProbe {
    nonisolated static let climateRecords:[(request:String,minimum:Int)]=[
        ("2134",4),("2122",6),("2123",7),("2120",6),("2121",6),("2110",7),("2111",4)
    ]
    static func run(expectedIdentity:[String:String]=VehicleIdentityProfile.bundled.expectedBodyIdentity,kind:ControlsCaptureKind,observation:String,
                    send:@escaping @MainActor(String)async throws->String,
                    isParked:@escaping @MainActor()->Bool,
                    now:@escaping @MainActor()->TimeInterval={ProcessInfo.processInfo.systemUptime})async throws->ControlsReport {
        try await withThrowingTaskGroup(of:ControlsReport.self){group in
            group.addTask{@MainActor in try await capture(expectedIdentity:expectedIdentity,kind:kind,observation:observation,send:send,isParked:isParked,now:now)}
            group.addTask{
                try await Task.sleep(nanoseconds:20_000_000_000)
                throw DiagnosticError.invalid("Parked capture time limit reached. Reconnect before retrying.")
            }
            defer{group.cancelAll()}
            guard let report=try await group.next() else{throw CancellationError()}
            return report
        }
    }
    private static func capture(expectedIdentity:[String:String],kind:ControlsCaptureKind,observation:String,send:(String)async throws->String,
                                isParked:()->Bool,now:()->TimeInterval)async throws->ControlsReport {
        let started=now()
        func check()throws {
            try Task.checkCancellation()
            let elapsed=now()-started
            guard elapsed.isFinite,(0...20).contains(elapsed),isParked() else{throw DiagnosticError.invalid("Parked capture interrupted")}
        }
        func bounded(_ command:String)async throws->String {
            try check();let result=try await send(command);try check();return result
        }
        func restore()async throws {
            for c in ["ATFCSM0","ATSH7DF","ATAR"]{_=try await bounded(c)}
        }
        var report=ControlsReport(started:Date(),kind:kind,observation:String(observation.prefix(160)))
        if kind == .preferences {
            let identity=try await BodyIdentityProbe.run(send:bounded,isParked:isParked,now:now)
            report.attempts=identity.attempts
            report.replies=identity.replies.map{.init(request:$0.request,responder:$0.responder,payloadHex:$0.payloadHex)}
            guard BodyDataProbe.matchesKnownIdentity(identity,expectedIdentity:expectedIdentity) else {
                report.outcome="No matching local vehicle profile; no preferences requested"
                return report // Identity probe already restored the engine route.
            }
        }
        let header=kind == .climate ? "688":"620",responder=kind == .climate ? "511":"504"
        for c in ["ATSH"+header,"ATCRA"+responder,"ATFCSH"+header,"ATFCSD30080A","ATFCSM1"]{_=try await bounded(c)}
        if kind == .climate {
            for request in ["1A87","1A9C"] {
                let raw=try await bounded(request)
                report.attempts.append(.init(request:request,reply:String(raw.prefix(4096))))
                do{report.replies.append(try ControlsReadReply.decode(raw,request:request,responder:responder,minimum:request=="1A87" ? 22:21))}
                catch{report.outcome="Climate identity unavailable or unexpected; no climate records requested";try await restore();return report}
            }
            // The OEM family shares record locations for versions0000–0004.
            // This gates raw applicability reads, not hardware validation or actions.
            let payloads=report.replies.map{reply in stride(from:0,to:reply.payloadHex.count,by:2).map{offset->UInt8 in
                let start=reply.payloadHex.index(reply.payloadHex.startIndex,offsetBy:offset)
                return UInt8(reply.payloadHex[start..<reply.payloadHex.index(start,offsetBy:2)],radix:16)!
            }}
            let hardware=payloads[0],software=payloads[1]
            let hv=UInt16(hardware[4])<<8 | UInt16(hardware[5]),sv=UInt16(software[5])<<8 | UInt16(software[6])
            let parts=[Array(hardware[12..<22]),Array(software[11..<21])]
            guard hv==sv,hv<=4,hardware[2..<4].elementsEqual(software[3..<5]),parts.allSatisfy({part in part.allSatisfy{(0x20...0x7E).contains($0)} && part.contains{(0x30...0x39).contains($0) || (0x41...0x5A).contains($0)}}) else {
                report.outcome="Climate identity outside candidate definitions; no climate records requested"
                try await restore();return report
            }
        }
        let records=kind == .climate ? climateRecords:[(request:"21B2",minimum:35)]
        for record in records {
            let raw=try await bounded(record.request)
            report.attempts.append(.init(request:record.request,reply:String(raw.prefix(4096))))
            do{report.replies.append(try ControlsReadReply.decode(raw,request:record.request,responder:responder,minimum:record.minimum))}
            catch{report.outcome="A record was unavailable or unexpected; capture stopped. Share this report.";try await restore();return report}
        }
        report.outcome=kind == .climate ? "Climate records captured; compare with the panel before interpreting":"Preferences captured; applicability and recovery still need checking"
        try await restore()
        return report
    }
}
