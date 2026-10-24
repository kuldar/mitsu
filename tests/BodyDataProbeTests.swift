import Foundation

@main struct BodyDataProbeTests {
    static let identity87=DiagnosticFixtures.identity87
    static let identity9C=DiagnosticFixtures.identity9C
    static func reply(_ command:String)->String {
        switch command {
        case "1A87":return identity87
        case "1A9C":return identity9C
        case "2178":return "504 03 61 78 64"
        case "217A":return "504 06 61 7A 81 01 00 11"
        case "217E":return "504 07 61 7E 3E 00 00 00 10"
        case "2173":return "504 06 61 73 08 00 00 00"
        default:return "OK"
        }
    }
    @MainActor static func main()async throws {
        var commands:[String]=[]
        let unconfigured=try await BodyDataProbe.run(send:{c in commands.append(c);return reply(c)},isParked:{true})
        precondition(unconfigured.replies.isEmpty && !commands.contains(where:{$0.hasPrefix("21")}))
        commands=[]

        let report=try await BodyDataProbe.run(expectedIdentity:DiagnosticFixtures.expectedIdentity,send:{c in commands.append(c);return reply(c)},isParked:{true})
        precondition(report.replies.map(\.request)==["2178","217A","217E","2173"])
        precondition(report.identity.replies.count==2)
        precondition(commands.suffix(3)==["ATFCSM0","ATSH7DF","ATAR"])
        precondition(report.note.lowercased().contains("unvalidated"))
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:folder)}
        let export=try report.export(to:folder)
        precondition(export.lastPathComponent=="Mitsu-body-data.json")
        let decoder=JSONDecoder();decoder.dateDecodingStrategy = .iso8601
        let restored=try decoder.decode(BodyDataReport.self,from:Data(contentsOf:export))
        precondition(restored.replies==report.replies)
        print("PASS positive capture and honest export")

        let latest=try report.persist(in:folder)
        let second=BodyDataReport(started:report.started.addingTimeInterval(60),identity:report.identity)
        _=try second.persist(in:folder)
        let archives=try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil).filter{$0.lastPathComponent.hasPrefix("body-capture-")}
        precondition(archives.count==2,"Repeated physical captures must not overwrite each other")
        let saved=try archives.map{try decoder.decode(BodyDataReport.self,from:Data(contentsOf:$0.appendingPathComponent("Mitsu-body-data.json")))}
        precondition(saved.filter{$0.replies==report.replies}.count==1)
        let newest=try decoder.decode(BodyDataReport.self,from:Data(contentsOf:latest))
        precondition(newest.replies.isEmpty)
        print("PASS capture history retained alongside latest export")

        commands=[]
        let mismatch=try await BodyDataProbe.run(expectedIdentity:DiagnosticFixtures.expectedIdentity,send:{c in
            commands.append(c)
            return c=="1A9C" ? identity9C.replacingOccurrences(of:"58 20",with:"59 20"):reply(c)
        },isParked:{true})
        precondition(mismatch.replies.isEmpty && !commands.contains(where:{$0.hasPrefix("21")}))
        precondition(commands.suffix(3)==["ATFCSM0","ATSH7DF","ATAR"])
        print("PASS mismatched exact identity prevents all body data reads")

        for bad in ["504 03 7F 21 31","505 03 61 78 00","504 03 61 79 00","504 03 61 78 00\r505 03 61 78 00","504 10 09 61 78 00 00 00 00"] {
            commands=[]
            let negative=try await BodyDataProbe.run(expectedIdentity:DiagnosticFixtures.expectedIdentity,send:{c in commands.append(c);return c=="2178" ? bad:reply(c)},isParked:{true})
            precondition(negative.replies.isEmpty && negative.attempts.count==1)
            precondition(!commands.contains("217A"))
            precondition(commands.suffix(3)==["ATFCSM0","ATSH7DF","ATAR"])
        }
        print("PASS negative, wrong responder/identifier and truncated frames stop and restore")

        var sent=0
        do{_=try await BodyDataProbe.run(expectedIdentity:DiagnosticFixtures.expectedIdentity,send:{c in sent += 1;return reply(c)},isParked:{false});preconditionFailure("Unparked must fail")}
        catch{}
        precondition(sent==0)
        for reason in ["cancel","unpark","deadline","restore","failedFinalRestore","unparkFinalRestore","deadlineFinalRestore"] {
            commands=[];var parked=true;var clock:TimeInterval=100
            var restores=0
            do {
                _=try await BodyDataProbe.run(expectedIdentity:DiagnosticFixtures.expectedIdentity,send:{c in
                    commands.append(c)
                    if c=="2178" {
                        if reason=="cancel"{throw CancellationError()}
                        if reason=="unpark"{parked=false}
                        if reason=="deadline"{clock += 21}
                    }
                    if c=="ATAR" {
                        restores += 1
                        if reason=="restore"{throw DiagnosticError.invalid("restore failed")}
                        if restores==2 && reason=="failedFinalRestore"{throw DiagnosticError.invalid("final restore failed")}
                        if restores==2 && reason=="unparkFinalRestore"{parked=false}
                        if restores==2 && reason=="deadlineFinalRestore"{clock += 21}
                    }
                    return reply(c)
                },isParked:{parked},now:{clock})
                preconditionFailure("Interrupted probe must throw")
            }catch{}
            if ["cancel","unpark","deadline"].contains(reason){precondition(!commands.contains("217A"))}
        }
        print("PASS parked, cancellation, continuation, deadline and restore guards")

        commands=[]
        let start=ProcessInfo.processInfo.systemUptime
        do {
            _=try await BodyDataProbe.run(expectedIdentity:DiagnosticFixtures.expectedIdentity,send:{c in
                commands.append(c)
                if c=="1A87"{try await Task.sleep(nanoseconds:25_000_000_000)}
                return reply(c)
            },isParked:{true})
            preconditionFailure("In-flight wait must be cancelled by overall deadline")
        }catch{}
        let elapsed=ProcessInfo.processInfo.systemUptime-start
        precondition(elapsed>=19 && elapsed<23,"Overall deadline failed: \(elapsed)")
        precondition(!commands.contains("1A9C"))
        print("PASS real overall deadline cancels an in-flight wait")
    }
}
