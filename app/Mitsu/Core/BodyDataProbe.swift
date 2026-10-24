import Foundation

struct BodyRecordReply:Codable,Equatable {
    let request:String
    let responder:String
    let payloadHex:String

    static func decode(_ frames:[CANFrame],request:String)throws->Self {
        guard BodyDataProbe.requests.contains(request),let identifier=UInt8(request.suffix(2),radix:16),
              frames.count==1,let frame=frames.first,frame.ecu=="504",
              (3...128).contains(frame.payload.count),frame.payload.prefix(2)==[0x61,identifier] else {
            throw DiagnosticError.invalid("No matching body data reply")
        }
        return Self(request:request,responder:frame.ecu,
                    payloadHex:frame.payload.map{String(format:"%02X",$0)}.joined())
    }
}

struct BodyDataReport:Codable {
    let started:Date
    let identity:BodyIdentityReport
    var observation=""
    var replies:[BodyRecordReply]=[]
    var attempts:[BodyIdentityReport.Attempt]=[]
    var outcome="No body data captured"
    var note="Unvalidated body records for physical comparison only; no live body states or vehicle settings validated. No VIN request."

    func export(to folder:URL)throws->URL {
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let file=folder.appendingPathComponent("Mitsu-body-data.json")
        let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys];encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(self).write(to:file,options:.atomic)
        return file
    }

    func persist(in folder:URL)throws->URL {
        let capture="body-capture-"+String(format:"%.3f",started.timeIntervalSince1970)
        _=try export(to:folder.appendingPathComponent(capture))
        return try export(to:folder)
    }
}

/// Four OEM-documented Data List records shared by the relevant GF# families.
/// This tests applicability. It deliberately does not publish decoded live states.
@MainActor enum BodyDataProbe {
    nonisolated static let requests=["2178","217A","217E","2173"]
    static func matchesKnownIdentity(_ identity:BodyIdentityReport,expectedIdentity:[String:String]=VehicleIdentityProfile.bundled.expectedBodyIdentity)->Bool {
        identity.replies.count==2 && Set(identity.replies.map(\.request)).count==2 &&
        identity.replies.allSatisfy{$0.responder=="504" && expectedIdentity[$0.request]==$0.payloadHex}
    }

    static func run(expectedIdentity:[String:String]=VehicleIdentityProfile.bundled.expectedBodyIdentity,send:@escaping @MainActor (String)async throws->String,isParked:@escaping @MainActor ()->Bool,observation:String="",
                    now:@escaping @MainActor ()->TimeInterval={ProcessInfo.processInfo.systemUptime})async throws->BodyDataReport {
        try await withThrowingTaskGroup(of:BodyDataReport.self) { group in
            group.addTask { @MainActor in try await capture(expectedIdentity:expectedIdentity,send:send,isParked:isParked,observation:observation,now:now) }
            group.addTask {
                try await Task.sleep(nanoseconds:20_000_000_000)
                throw DiagnosticError.invalid("Body capture time limit reached. Reconnect before retrying.")
            }
            // BluetoothClient's cancellation handler disconnects and releases any
            // pending reply. A late response cannot keep the capture alive.
            defer{group.cancelAll()}
            guard let result=try await group.next() else{throw CancellationError()}
            return result
        }
    }

    private static func capture(expectedIdentity:[String:String],send:(String)async throws->String,isParked:()->Bool,observation:String,
                                now:()->TimeInterval)async throws->BodyDataReport {
        let clock=now(),date=Date()
        func checkBounds()throws {
            try Task.checkCancellation()
            let elapsed=now()-clock
            guard elapsed.isFinite,(0...20).contains(elapsed),isParked() else {
                throw DiagnosticError.invalid("Parked body capture interrupted or time limit reached")
            }
        }
        func bounded(_ command:String)async throws->String {
            try checkBounds()
            let response=try await send(command)
            try checkBounds()
            return response
        }
        // This existing probe also restores the engine route before returning.
        let identity=try await BodyIdentityProbe.run(send:bounded,isParked:isParked,now:now)
        var report=BodyDataReport(started:date,identity:identity,observation:String(observation.prefix(160)))
        guard matchesKnownIdentity(identity,expectedIdentity:expectedIdentity) else {
            report.outcome="No matching local vehicle profile; no body data requested"
            return report
        }
        for command in ["ATSH620","ATCRA504","ATFCSH620","ATFCSD30080A","ATFCSM1"]{_=try await bounded(command)}
        for request in requests {
            let response=try await bounded(request)
            report.attempts.append(.init(request:request,reply:String(response.prefix(4096))))
            do{report.replies.append(try BodyRecordReply.decode(OBDCodec.frames(response),request:request))}
            catch{
                report.outcome="Body record unavailable or unexpected; capture stopped. Share the report."
                break
            }
        }
        if report.replies.count==requests.count {
            report.outcome="Four body records captured; physical state comparison still needed"
        }
        for command in ["ATFCSM0","ATSH7DF","ATAR"]{_=try await bounded(command)}
        try Task.checkCancellation()
        return report
    }
}
