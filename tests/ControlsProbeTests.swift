import Foundation

@main struct ControlsProbeTests {
    static func identity(_ request:String,version:UInt8=0)->String {
        let header:[UInt8] = request == "1A87" ? [0x5A,0x87,0x80,0x08,0,version,0,0,0,0,0,0]:[0x5A,0x9C,0,0x80,0x08,0,version,0,0,0,0]
        // Synthetic part numbers: transport fixture only, never evidence for a real car.
        return framed(header+Array("7820A123  ".utf8)+[0x20],ecu:"511")
    }
    static func framed(_ bytes:[UInt8],ecu:String)->String {
        if bytes.count<=7{return ecu+" "+([UInt8(bytes.count)]+bytes).map{String(format:"%02X",$0)}.joined(separator:" ")}
        var lines=[ecu+" "+([0x10,UInt8(bytes.count)]+Array(bytes.prefix(6))).map{String(format:"%02X",$0)}.joined(separator:" ")]
        var i=6,seq:UInt8=1
        while i<bytes.count{let next=min(i+7,bytes.count);lines.append(ecu+" "+([0x20+seq]+Array(bytes[i..<next])).map{String(format:"%02X",$0)}.joined(separator:" "));i=next;seq=(seq+1)%16}
        return lines.joined(separator:"\r")
    }
    static func climate(_ c:String)->String {
        if c.hasPrefix("AT"){return "OK"}
        if c.hasPrefix("1A"){return identity(c)}
        let id=UInt8(c.suffix(2),radix:16)!
        return framed([0x61,id]+Array(repeating:0x28,count:14),ecu:"511")
    }
    @MainActor static func main()async throws {
        var sent:[String]=[]
        let good=try await ControlsProbe.run(expectedIdentity:DiagnosticFixtures.expectedIdentity,kind:.climate,observation:"Panel 20°C, fan low",send:{c in sent.append(c);return climate(c)},isParked:{true})
        precondition(good.replies.count==9 && good.observation=="Panel 20°C, fan low")
        precondition(sent.suffix(3)==["ATFCSM0","ATSH7DF","ATAR"])
        precondition(!sent.contains(where:{$0.hasPrefix("30") || $0.hasPrefix("3B") || $0.hasPrefix("10")}))
        precondition(good.note.lowercased().contains("unvalidated"))
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:folder)}
        _=try good.persist(in:folder)
        var second=good;second.started=good.started.addingTimeInterval(60);second.observation="Restored"
        let url=try second.persist(in:folder)
        let decoder=JSONDecoder();decoder.dateDecodingStrategy = .iso8601
        let saved=try decoder.decode(ControlsReport.self,from:Data(contentsOf:url))
        precondition(saved.observation=="Restored" && saved.replies==good.replies)
        let archives=try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil).filter{$0.lastPathComponent.hasPrefix("controls-capture-")}
        precondition(archives.count==2)
        print("PASS climate raw capture, provenance, restore and archive/export")
        for version:UInt8 in [0,1,2,3,4] {
            let r=try await ControlsProbe.run(expectedIdentity:DiagnosticFixtures.expectedIdentity,kind:.climate,observation:"",send:{c in c.hasPrefix("1A") ? identity(c,version:version):climate(c)},isParked:{true})
            precondition(r.replies.count==9)
        }
        for mode in ["unknownVersion","disagreeingVersion","shortIdentity","wrongECU","multipleECUs","negativeIdentity","familyMismatch","nonAsciiPart"] {
            sent=[]
            let r=try await ControlsProbe.run(expectedIdentity:DiagnosticFixtures.expectedIdentity,kind:.climate,observation:"",send:{c in
                sent.append(c)
                if c=="1A87" {
                    if mode=="unknownVersion"{return identity(c,version:5)}
                    if mode=="shortIdentity"{return "511 06 5A 87 80 08 00 00"}
                    if mode=="wrongECU"{return identity(c).replacingOccurrences(of:"511",with:"504")}
                    if mode=="multipleECUs"{return identity(c)+"\r"+identity(c).replacingOccurrences(of:"511",with:"504")}
                    if mode=="negativeIdentity"{return "511 03 7F 1A 12"}
                    if mode=="nonAsciiPart"{return identity(c).replacingOccurrences(of:"37",with:"FF")}
                }
                if c=="1A9C" && mode=="disagreeingVersion"{return identity(c,version:1)}
                if c=="1A9C" && mode=="familyMismatch"{return identity(c).replacingOccurrences(of:"80 08",with:"80 09")}
                return climate(c)
            },isParked:{true})
            precondition(!sent.contains(where:{$0.hasPrefix("21")}),mode)
            precondition(sent.suffix(3)==["ATFCSM0","ATSH7DF","ATAR"] && !r.outcome.contains("captured"))
        }
        print("PASS unknown/inconsistent/short/negative climate identity prevents records")
        for bad in ["511 03 7F 21 31","511 03 61 34 28","511 04 61 35 28 28","512 04 61 34 28 28","511 10 09 61 34 28 28 28 28"] {
            sent=[]
            let r=try await ControlsProbe.run(expectedIdentity:DiagnosticFixtures.expectedIdentity,kind:.climate,observation:"",send:{c in sent.append(c);return c=="2134" ? bad:climate(c)},isParked:{true})
            precondition(r.replies.count==2 && !sent.contains("2122") && sent.suffix(3)==["ATFCSM0","ATSH7DF","ATAR"])
        }
        print("PASS first invalid record stops and restores")
        func body(_ c:String)->String {
            if c=="1A87"{return DiagnosticFixtures.identity87}
            if c=="1A9C"{return DiagnosticFixtures.identity9C}
            if c=="21B2"{return framed([0x61,0xB2]+Array(repeating:0,count:33),ecu:"504")}
            return "OK"
        }
        sent=[]
        let prefs=try await ControlsProbe.run(expectedIdentity:DiagnosticFixtures.expectedIdentity,kind:.preferences,observation:String(repeating:"a",count:300),send:{c in sent.append(c);return body(c)},isParked:{true})
        precondition(prefs.replies.count==3 && prefs.observation.count==160 && prefs.note.contains("not a full"))
        for mode in ["mismatch","short"] {
            sent=[]
            let r=try await ControlsProbe.run(expectedIdentity:DiagnosticFixtures.expectedIdentity,kind:.preferences,observation:"",send:{c in
                sent.append(c)
                if c=="1A9C" && mode=="mismatch"{return body(c).replacingOccurrences(of:"58 20",with:"59 20")}
                if c=="21B2" && mode=="short"{return framed([0x61,0xB2]+Array(repeating:0,count:32),ecu:"504")}
                return body(c)
            },isParked:{true})
            if mode=="mismatch"{precondition(!sent.contains("21B2"))}
            precondition(r.replies.count<=2 && sent.suffix(3)==["ATFCSM0","ATSH7DF","ATAR"])
        }
        print("PASS preferences exact identity, short snapshot rejection, bounded observation")
        sent=[]
        do{_=try await ControlsProbe.run(expectedIdentity:DiagnosticFixtures.expectedIdentity,kind:.climate,observation:"",send:{c in sent.append(c);return climate(c)},isParked:{false});preconditionFailure()}catch{}
        precondition(sent.isEmpty)
        for mode in ["cancel","unpark","deadline","restore","finalUnpark"] {
            var parked=true,clock:TimeInterval=1;sent=[]
            do{
                _=try await ControlsProbe.run(expectedIdentity:DiagnosticFixtures.expectedIdentity,kind:.climate,observation:"",send:{c in
                    sent.append(c)
                    if c=="2134" {
                        if mode=="cancel"{throw CancellationError()}
                        if mode=="unpark"{parked=false}
                        if mode=="deadline"{clock += 21}
                    }
                    if c=="ATAR" && mode=="restore"{throw DiagnosticError.invalid("restore failed")}
                    if c=="ATAR" && mode=="finalUnpark"{parked=false}
                    return climate(c)
                },isParked:{parked},now:{clock})
                preconditionFailure(mode)
            }catch{}
            if ["cancel","unpark","deadline"].contains(mode){precondition(!sent.contains("2122"))}
        }
        print("PASS parked, cancellation, deadline and restore failures propagate")
        let start=ProcessInfo.processInfo.systemUptime
        do{_=try await ControlsProbe.run(expectedIdentity:DiagnosticFixtures.expectedIdentity,kind:.climate,observation:"",send:{c in if c=="1A87"{try await Task.sleep(nanoseconds:25_000_000_000)};return climate(c)},isParked:{true});preconditionFailure()}catch{}
        precondition(ProcessInfo.processInfo.systemUptime-start<23)
        print("PASS overall deadline cancels in-flight read")
    }
}
