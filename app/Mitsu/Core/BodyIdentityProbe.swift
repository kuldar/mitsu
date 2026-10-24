import Foundation

/// Bounded identity discovery. Transport/configuration failures propagate to the
/// session, which disconnects. Only a completed route restore permits polling.
@MainActor enum BodyIdentityProbe {
    static func run(send:(String)async throws->String,isParked:()->Bool,now:()->TimeInterval={ProcessInfo.processInfo.systemUptime})async throws->BodyIdentityReport {
        guard isParked() else{throw DiagnosticError.invalid("Confirm you're parked before checking")}
        let started=now()
        func bounded(_ command:String)async throws->String {
            try Task.checkCancellation()
            let elapsed=now()-started
            guard elapsed.isFinite,(0...12).contains(elapsed),isParked() else{throw DiagnosticError.invalid("Parked check interrupted or time limit reached")}
            return try await send(command)
        }
        var report=BodyIdentityReport(started:Date())
        for command in ["ATSH620","ATCRA504","ATFCSH620","ATFCSD30080A","ATFCSM1"]{_=try await bounded(command)}
        for identifier:UInt8 in [0x87,0x9C] {
            try Task.checkCancellation()
            guard isParked() else{throw DiagnosticError.invalid("Parked check interrupted")}
            let request=String(format:"1A%02X",identifier)
            let response=try await bounded(request)
            report.attempts.append(.init(request:request,reply:String(response.prefix(4096))))
            do{report.replies.append(try BodyIdentityReply.decode(OBDCodec.frames(response),identifier:identifier))}
            catch{
                report.outcome=report.replies.isEmpty ? "No matching identity reply. A compatible diagnostic session or route may be required.":"Partial identity obtained; further read was unavailable."
                break
            }
        }
        if report.replies.count==2{report.outcome="Controller responded; body data definitions still need matching"}
        for command in ["ATFCSM0","ATSH7DF","ATAR"]{_=try await bounded(command)}
        try Task.checkCancellation()
        return report
    }
}
