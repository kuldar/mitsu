import Foundation

@MainActor final class DiagnosticSession: ObservableObject {
    @Published private(set) var status="Waiting for adapter"
    @Published private(set) var live=false
    @Published private(set) var codes: [String]=[]
    @Published private(set) var codesRead=false
    @Published private(set) var supported: [String:Set<UInt8>]=[:]
    @Published private(set) var bodyCheckStatus="Not checked on this car"
    @Published private(set) var bodyReport:BodyIdentityReport?
    @Published private(set) var checkingBody=false
    @Published private(set) var bodyDataStatus="Not captured on this car"
    @Published private(set) var bodyDataReport:BodyDataReport?
    @Published private(set) var controlsStatus="Ready for a parked, read-only capture"
    @Published private(set) var controlsReport:ControlsReport?
    @Published private(set) var requestControls:ControlsCaptureRequest?
    private var requestBodyObservation=""
    var onSample: ((Sample)->Void)?
    var onStop: (()->Void)?
    @Published private(set) var requestCodes=false
    @Published private(set) var requestSteering=false
    @Published private(set) var checkingAuxiliary=false
    var diagnosticCheckBusy:Bool{checkingBody || checkingAuxiliary || requestCodes || requestSteering || requestBodyIdentity || requestBodyData || requestControls != nil}
    @Published private(set) var requestBodyIdentity=false
    @Published private(set) var requestBodyData=false
    var parkedForBodyCheck:(()->Bool)?
    var bodyCheckStillParked:(()->Bool)?
    let bluetooth: BluetoothClient
    private var task: Task<Void,Never>?
    private var route=DiagnosticRouteState()
    init(bluetooth: BluetoothClient) {
        self.bluetooth=bluetooth
        bluetooth.onReady = { [weak self] in self?.begin() }
        bluetooth.onDisconnect = { [weak self] in self?.stop() }
    }
    enum Check {
        case codes,steering,bodyIdentity,bodyData(String),controls(ControlsCaptureRequest)
    }
    @discardableResult func enqueue(_ check:Check)->Bool {
        guard !diagnosticCheckBusy else{return false}
        switch check {
        case .codes:requestCodes=true
        case .steering:requestSteering=true
        case .bodyIdentity:requestBodyIdentity=true
        case .bodyData(let observation):requestBodyObservation=String(observation.prefix(160));requestBodyData=true
        case .controls(let request):requestControls=request
        }
        return true
    }
    func stop() { task?.cancel(); task=nil; live=false; route=DiagnosticRouteState(); supported=[:];requestCodes=false;requestSteering=false;requestBodyIdentity=false;requestBodyData=false;requestControls=nil;requestBodyObservation="";checkingBody=false;checkingAuxiliary=false;codes=[];codesRead=false; onStop?() }
    private func begin() {
        stop(); codesRead=false; codes=[]
        task=Task {
            do { try await run() }
            catch is CancellationError { }
            catch { self.status=error.localizedDescription; self.bluetooth.disconnect() }
        }
    }
    private func command(_ command: String) async throws -> String {
        try Task.checkCancellation()
        guard ReadPolicy.allowed(command,vehicle:true),ReadPolicy.allowedOnHeader(command,header:route.header) else { throw DiagnosticError.invalid("Read policy rejected the diagnostic route") }
        if ReadPolicy.reads.contains(command) || command.hasPrefix("21") || command.hasPrefix("1A") { guard route.canRead(command) else { throw DiagnosticError.invalid("Diagnostic route is not established") } }
        let reply=OBDCodec.withoutEcho(try await bluetooth.send(command),command:command)
        try Task.checkCancellation()
        if ["CAN ERROR","BUS ERROR","BUFFER FULL","RX ERROR","STOPPED","UNABLE TO CONNECT","BUS BUSY","?"].contains(where:{reply.contains($0)}) { throw DiagnosticError.invalid("Adapter reported an error. Reconnect to resume.") }
        if command.hasPrefix("AT"), !["ATI","ATRV"].contains(command) {
            guard reply.trimmingCharacters(in:.whitespacesAndNewlines) == "OK" else { throw DiagnosticError.invalid("Adapter configuration was not acknowledged") }
            route.acknowledge(command)
        }
        try await Task.sleep(nanoseconds:100_000_000)
        return reply
    }
    private func standardRoute() async throws {
        for c in ["ATFCSM0","ATSH7DF","ATAR"] { _ = try await command(c) }
    }
    private func run() async throws {
        status="Identifying adapter…"
        let identity=try await command("ATI")
        guard identity.uppercased().contains("ELM") else { throw DiagnosticError.invalid("Adapter did not identify an ELM diagnostic channel") }
        _ = try await command("ATE0")
        let v=try await command("ATRV")
        guard let voltage=Double(v.trimmingCharacters(in:.whitespacesAndNewlines).replacingOccurrences(of:"V",with:"")), (12...15.5).contains(voltage) else { throw DiagnosticError.invalid("Supply voltage is outside the 12–15.5 V preflight range. Check the vehicle battery before retrying.") }
        onSample?(Sample(signal:.supply,value:voltage,ecu:"Adapter",uptime:ProcessInfo.processInfo.systemUptime,source:.live))
        for c in ["ATE0","ATL0","ATS1","ATH1","ATD0","ATM0","ATCAF1","ATCFC1","ATAT1","ATST64","ATSP6"] { _ = try await command(c) }
        try await standardRoute()
        status="Discovering supported readings…"
        for base in stride(from:0,through:224,by:32) {
            if base > 0 && !supported.values.contains(where:{$0.contains(UInt8(base))}) { break }
            let reply=try await command(String(format:"01%02X",base))
            for frame in try OBDCodec.frames(reply) where ["7E8","7E9"].contains(frame.ecu) {
                guard frame.payload.count == 6, frame.payload[0] == 0x41, frame.payload[1] == UInt8(base) else { throw DiagnosticError.invalid("Capability reply did not match its request") }
                if base > 0 && supported[frame.ecu]?.contains(UInt8(base)) != true { continue }
                supported[frame.ecu,default:[]].formUnion(try OBDCodec.supported(Array(frame.payload.dropFirst(2)),base:base))
            }
        }
        guard supported.values.contains(where:{$0.contains(12) || $0.contains(13)}) else { throw DiagnosticError.invalid("No supported engine readings found") }
        live=true; status="Live engine data"
        let slow: [Signal]=[.coolant,.voltage,.load,.airflow,.throttle,.intake]
        var iteration=0
        while !Task.isCancelled {
            for signal in [Signal.speed,.rpm,slow[iteration % slow.count]] {
                guard let pid=signal.pid, supported.values.contains(where:{$0.contains(pid)}) else { continue }
                let reply=try await command(String(format:"01%02X",pid))
                if reply.trimmingCharacters(in:.whitespacesAndNewlines) == "NO DATA" { continue }
                let frames=try OBDCodec.validatedSignalFrames(OBDCodec.frames(reply),pid:pid,supported:supported)
                // Prefer the engine ECU, while retaining each responder's capability identity.
                guard let frame=frames.first else { throw DiagnosticError.invalid("Unexpected responding ECU") }
                let value=try OBDCodec.decode(frame,pid:pid)
                onSample?(Sample(signal:signal,value:value,ecu:frame.ecu,uptime:ProcessInfo.processInfo.systemUptime,source:.live))
                try await Task.sleep(nanoseconds:150_000_000)
            }
            if requestCodes {
                checkingAuxiliary=true;defer{checkingAuxiliary=false}
                requestCodes=false; var results:[String]=[]
                for service: UInt8 in [3,7] {
                    let response=try await command(String(format:"%02X",service))
                    if response.trimmingCharacters(in:.whitespacesAndNewlines) == "NO DATA" { throw DiagnosticError.invalid("Emissions fault read returned no data") }
                    for frame in try OBDCodec.frames(response) { results += try OBDCodec.dtcs(frame,service:service) }
                }
                codes=Array(Set(results)).sorted(); codesRead=true
            }
            if requestSteering {
                checkingAuxiliary=true;defer{checkingAuxiliary=false}
                requestSteering=false
                for c in ["ATSH7B6","ATCRA7B7","ATFCSH7B6","ATFCSD30080A","ATFCSM1"] { _ = try await command(c) }
                let response=try await command("2104")
                let frames=try OBDCodec.frames(response)
                guard frames.count == 1 else { throw DiagnosticError.invalid("Unexpected steering responders") }
                onSample?(Sample(signal:.steering,value:try OBDCodec.steering(frames[0]),ecu:"7B7",uptime:ProcessInfo.processInfo.systemUptime,source:.live))
                try await standardRoute()
            }
            if requestBodyIdentity {
                requestBodyIdentity=false
                if parkedForBodyCheck?() == true {try await identifyBodyController()}
                else{bodyCheckStatus="Confirm you're parked before checking"}
            }
            if requestBodyData {
                requestBodyData=false
                if parkedForBodyCheck?() == true {try await captureBodyData(observation:requestBodyObservation)}
                else{bodyDataStatus="Confirm you're parked before capturing"}
            }
            if let request=requestControls {
                requestControls=nil
                if parkedForBodyCheck?() == true {try await captureControls(request)}
                else{controlsStatus="Confirm you're parked before capturing"}
            }
            iteration += 1
        }
    }

    private func identifyBodyController()async throws {
        checkingBody=true;bodyCheckStatus="Checking body controller…"
        defer{checkingBody=false}
        do {
            // Fresh zero speed was checked immediately before entering here.
            // Engine polling pauses during the bounded probe, so its last speed
            // sample may expire; continue to respect the user's parked state.
            let report=try await BodyIdentityProbe.run(send:{try await self.command($0)},isParked:{self.bodyCheckStillParked?() == true})
            bodyReport=report;bodyCheckStatus=report.outcome
        } catch {
            bodyCheckStatus="Check interrupted. Reconnect before retrying."
            throw error
        }
    }

    private func captureBodyData(observation:String)async throws {
        checkingBody=true;bodyDataStatus="Reading four documented body records…"
        defer{checkingBody=false}
        do {
            let report=try await BodyDataProbe.run(send:{try await self.command($0)},isParked:{self.bodyCheckStillParked?() == true},observation:observation)
            bodyDataReport=report;bodyDataStatus=report.outcome
            do {
                let documents=try FileManager.default.url(for:.documentDirectory,in:.userDomainMask,appropriateFor:nil,create:true)
                _=try report.persist(in:documents.appendingPathComponent("Diagnostics"))
            } catch {
                bodyDataStatus += ". Couldn't save automatically; prepare and share the report."
            }
        } catch {
            bodyDataStatus="Capture interrupted. Reconnect before retrying."
            throw error
        }
    }
    private func captureControls(_ request:ControlsCaptureRequest)async throws {
        checkingBody=true;controlsStatus="Reading "+request.kind.title.lowercased()+"…"
        defer{checkingBody=false}
        do {
            let report=try await ControlsProbe.run(kind:request.kind,observation:request.observation,
                send:{try await self.command($0)},isParked:{self.bodyCheckStillParked?() == true})
            controlsReport=report;controlsStatus=report.outcome
            do {
                let documents=try FileManager.default.url(for:.documentDirectory,in:.userDomainMask,appropriateFor:nil,create:true)
                _=try report.persist(in:documents.appendingPathComponent("Diagnostics"))
            } catch {controlsStatus += ". Couldn't save automatically; prepare and share this report."}
        } catch {
            controlsStatus="Capture interrupted. Reconnect before retrying."
            throw error
        }
    }

}
