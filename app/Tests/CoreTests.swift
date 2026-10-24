import Foundation

@main struct CoreTests {
    static func main() throws {
        var failures = 0
        var count = 0
        func check(_ title: String, _ body: () throws -> Bool) {
            count += 1
            do { if try body() { print("PASS \(title)") } else { failures += 1; print("FAIL \(title)") } }
            catch { failures += 1; print("FAIL \(title): \(error)") }
        }
        func rejects(_ body: () throws -> Void) -> Bool { do { try body(); return false } catch { return true } }
        check("Public vehicle profile defaults to no accepted identity") {
            VehicleIdentityProfile.decode(nil).expectedBodyIdentity.isEmpty && VehicleIdentityProfile.decode(Data("{}".utf8)).expectedBodyIdentity.isEmpty
        }
        check("Complete synthetic local profile accepts only exact complete uppercase payloads") {
            let payloads=["1A87":"5A87"+String(repeating:"00",count:20),"1A9C":"5A9C"+String(repeating:"00",count:19)]
            let data=try JSONSerialization.data(withJSONObject:["expectedBodyIdentity":payloads])
            return VehicleIdentityProfile.decode(data).expectedBodyIdentity==payloads
        }
        check("Malformed vehicle profiles fail closed") {
            ["{\"expectedBodyIdentity\":{\"1A87\":\"FFFF\",\"1A9C\":\"FFFF\"}}", "{\"expectedBodyIdentity\":{\"1A87\":\"5A87ZZ\"}}"].allSatisfy { VehicleIdentityProfile.decode(Data($0.utf8)).expectedBodyIdentity.isEmpty }
        }
        check("RPM is decoded from matching service and PID") {
            try OBDCodec.decode(CANFrame(ecu: "7E8", payload: [0x41,0x0C,0x0B,0xB8]), pid: 0x0C) == 750
        }
        check("wrong PID is rejected") { rejects { _ = try OBDCodec.decode(CANFrame(ecu:"7E8",payload:[0x41,0x0D,0]), pid:0x0C) } }
        check("truncated RPM rejected") { rejects { _ = try OBDCodec.decode(CANFrame(ecu:"7E8",payload:[0x41,0x0C,0]), pid:0x0C) } }
        check("unsupported fuel rejected") { rejects { _ = try OBDCodec.decode(CANFrame(ecu:"7E8",payload:[0x41,0x2F,128]), pid:0x2F) } }
        check("CAN multiple responders retained") { try OBDCodec.frames("7E8 04 41 0C 0B B8\r7E9 04 41 0C 0B B8").map(\.ecu) == ["7E8","7E9"] }
        check("ISO-TP assembly") { try OBDCodec.frames("7B7 10 09 61 04 10 00 00 00\r7B7 21 00 00 00 00 00 00 00").first?.payload == [0x61,4,0x10,0,0,0,0,0,0] }
        check("ISO-TP missing continuation rejected") { rejects { _ = try OBDCodec.frames("7B7 10 09 61 04 10 00 00 00") } }
        check("ISO-TP sequence gap rejected") { rejects { _ = try OBDCodec.frames("7B7 10 09 61 04 10 00 00 00\r7B7 22 00 00 00 00 00 00 00") } }
        check("unexpected CAN text rejected") { rejects { _ = try OBDCodec.frames("OK") } }
        check("capability bitmap") { try OBDCodec.supported([0x80,0,0,1],base:0) == [1,32] }
        check("steering only from known responder") { rejects { _ = try OBDCodec.steering(CANFrame(ecu:"7E8",payload:[0x61,4,0x10,0])) } }
        check("steering center") { try OBDCodec.steering(CANFrame(ecu:"7B7",payload:[0x61,4,0x10,0])) == 0 }
        check("stored DTC decoding") { try OBDCodec.dtcs(CANFrame(ecu:"7E8",payload:[0x43,0x01,0x33,0,0]), service:3) == ["P0133"] }
        check("observed CAN zero-count DTC reply") {try OBDCodec.dtcs(CANFrame(ecu:"7E8",payload:[0x43,0]),service:3).isEmpty}
        check("CAN count-prefixed DTC reply") {try OBDCodec.dtcs(CANFrame(ecu:"7E8",payload:[0x43,1,0x01,0x33]),service:3) == ["P0133"]}
        check("truncated count-prefixed DTC rejected") {rejects{_=try OBDCodec.dtcs(CANFrame(ecu:"7E8",payload:[0x43,2,0x01,0x33]),service:3)}}
        check("split notifications wait for prompt") {
            var p=PromptBuffer(); return try p.feed(Data("7E8 04 41".utf8)) == nil && p.feed(Data(" 0C 0B B8\r>".utf8)) == "7E8 04 41 0C 0B B8\r"
        }
        check("bytes after prompt rejected") { var p=PromptBuffer(); return rejects { _ = try p.feed(Data("OK>garbage".utf8)) } }
        check("oversized notification rejected") { var p=PromptBuffer(); return rejects { _ = try p.feed(Data(repeating:65,count:65537)) } }
        let fresh=Sample(signal:.speed,value:36,ecu:"7E8",uptime:100,source:.live)
        check("fresh at 2 seconds") { fresh.isFresh(at:102) }
        check("stale after 3 seconds") { !fresh.isFresh(at:104) }
        check("future/nonfinite samples rejected") { !fresh.isFresh(at:99) && !Sample(signal:.speed,value:.nan,ecu:"7E8",uptime:100,source:.live).isFresh(at:101) }
        check("disconnected value is unavailable") { VehicleSnapshot(samples:[.speed:fresh]).value(.speed,at:101,connected:false,preview:false) == nil }
        check("preview cannot become live value") { VehicleSnapshot(samples:[.speed:Sample(signal:.speed,value:80,ecu:"PREVIEW",uptime:100,source:.preview)]).value(.speed,at:101,connected:true,preview:false) == nil }
        check("trip integrates live speed trapezoid") { var t=TripAccumulator(); t.accept(fresh); t.accept(Sample(signal:.speed,value:36,ecu:"7E8",uptime:102,source:.live)); return abs(t.distanceKM-0.02)<0.000001 && t.coveredSeconds == 2 }
        check("interleaved RPM and coolant do not erase trip speed continuity") {
            var t=TripAccumulator();t.accept(fresh)
            t.accept(Sample(signal:.rpm,value:750,ecu:"7E8",uptime:100.3,source:.live))
            t.accept(Sample(signal:.coolant,value:80,ecu:"7E8",uptime:100.6,source:.live))
            t.accept(Sample(signal:.speed,value:36,ecu:"7E8",uptime:101,source:.live))
            return abs(t.distanceKM-0.01)<0.000001
        }
        check("short non-final ISO-TP continuation rejected") {rejects{_=try OBDCodec.frames("7B7 10 09 61 04 10 00 00 00\r7B7 21 AA\r7B7 22 BB\r7B7 23 CC")}}
        check("preview and replay cannot authorize vehicle connections") {!SampleSource.preview.permitsVehicleConnection && !SampleSource.replay.permitsVehicleConnection && SampleSource.live.permitsVehicleConnection}
        check("cancelled authorization exchange cannot restore a signed-out account") {var epoch=AuthorizationEpoch();let first=epoch.begin();epoch.invalidate();return !epoch.isCurrent(first)}
        check("previous account response cannot update a reconnected account") {var epoch=AuthorizationEpoch();let first=epoch.begin();let second=epoch.begin();return !epoch.isCurrent(first) && epoch.isCurrent(second)}
        check("trip skips gaps and preview") { var t=TripAccumulator(); t.accept(fresh); t.accept(Sample(signal:.speed,value:36,ecu:"7E8",uptime:110,source:.live)); t.accept(Sample(signal:.speed,value:36,ecu:"PREVIEW",uptime:111,source:.preview)); return t.distanceKM == 0 }
        check("trip interrupt prevents bridging disconnect") { var t=TripAccumulator(); t.accept(fresh); t.interrupt(); t.accept(Sample(signal:.speed,value:36,ecu:"7E8",uptime:101,source:.live)); return t.distanceKM == 0 }
        check("weather expiry and area mismatch") { WeatherFreshness.evaluate(age:1801,sameArea:true) == .cached && WeatherFreshness.evaluate(age:10801,sameArea:true) == .expired && WeatherFreshness.evaluate(age:1,sameArea:false) == .expired }
        check("OAuth callback validates scheme host state and code") { try OAuthCallback.validate(URL(string:"com.example.mitsu://spotify-callback?state=abc&code=xyz")!,state:"abc") == "xyz" }
        check("OAuth state mismatch rejected") { rejects { _ = try OAuthCallback.validate(URL(string:"com.example.mitsu://spotify-callback?state=bad&code=xyz")!,state:"abc") } }
        check("OAuth wrong host rejected") { rejects { _ = try OAuthCallback.validate(URL(string:"com.example.mitsu://evil?state=abc&code=xyz")!,state:"abc") } }
        check("Spotify empty forbidden and rate limit policies") { PlaybackResponse.classify(status:204,retryAfter:nil) == .empty && PlaybackResponse.classify(status:403,retryAfter:nil) == .forbidden && PlaybackResponse.classify(status:429,retryAfter:"12") == .retry(after:12) }
        check("route state resets on a new session") { !DiagnosticRouteState().canRead("010C") }
        check("ELM exact command echo is removed before parsing") { OBDCodec.withoutEcho("ATRV\r14.1V\r",command:"ATRV") == "14.1V" }
        check("unexpected echo text is not stripped") { OBDCodec.withoutEcho("OTHER\rOK",command:"ATE0") == "OTHER\rOK" }
        check("control and injection commands forbidden") { !ReadPolicy.allowed("04",vehicle:true) && !ReadPolicy.allowed("010C\r04",vehicle:true) && !ReadPolicy.allowed("2E1234",vehicle:true) }
        check("all ECU replies must match requested PID") {rejects{_=try OBDCodec.validatedSignalFrames([CANFrame(ecu:"7E8",payload:[0x41,13,0]),CANFrame(ecu:"7E9",payload:[0x41,12,0,0])],pid:13,supported:["7E8":[13],"7E9":[13]])}}
        check("unknown responders cannot hide behind valid ECU") {rejects{_=try OBDCodec.validatedSignalFrames([CANFrame(ecu:"7E8",payload:[0x41,13,0]),CANFrame(ecu:"123",payload:[0x41,13,0])],pid:13,supported:["7E8":[13]])}}
        check("conflicting duplicate ECU samples rejected") {rejects{_=try OBDCodec.validatedSignalFrames([CANFrame(ecu:"7E8",payload:[0x41,13,0]),CANFrame(ecu:"7E8",payload:[0x41,13,40])],pid:13,supported:["7E8":[13]])}}
        check("rapid same-device reconnect waits for prior disconnect") {var l=BLELifecycle();let id=UUID();guard l.begin(id),l.connected(id) else{return false};l.disconnect(id);return !l.begin(id) && !l.notifications(id) && l.disconnected(id) && l.begin(id)}
        check("late or repeated notification readiness ignored") {var l=BLELifecycle();let id=UUID();_=l.begin(id);return !l.notifications(id)}
        check("unreadable journey history is preserved before a future save") {
            let dir=FileManager.default.temporaryDirectory.appendingPathComponent("mitsu-history-test-"+UUID().uuidString)
            try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true);defer{try? FileManager.default.removeItem(at:dir)}
            let file=dir.appendingPathComponent("journeys.json"),original=Data("unreadable original history".utf8)
            try original.write(to:file)
            guard rejects({_=try HistoryArchive.load(from:file)}) else{return false}
            try Data("[]".utf8).write(to:file)
            let backups=try FileManager.default.contentsOfDirectory(at:dir,includingPropertiesForKeys:nil).filter{$0.lastPathComponent != file.lastPathComponent}
            return try backups.count==1 && Data(contentsOf:backups[0])==original
        }
        check("body state expires and stays source isolated") {
            var body=BodySnapshot()
            body.samples[.lowBeam]=BodySample(value:true,uptime:100,source:.live)
            return body.value(.lowBeam,at:101,connected:true,preview:false) == true &&
                body.value(.lowBeam,at:104,connected:true,preview:false) == nil &&
                body.value(.lowBeam,at:99,connected:true,preview:false) == nil &&
                body.value(.lowBeam,at:101,connected:false,preview:false) == nil &&
                body.value(.lowBeam,at:101,connected:true,preview:true) == nil
        }
        check("unknown doors are not closed and replay never becomes live") {
            var body=BodySnapshot()
            body.samples[.doorFL]=BodySample(value:false,uptime:100,source:.replay)
            return body.value(.doorFR,at:101,connected:true,preview:false) == nil &&
                body.value(.doorFL,at:101,connected:true,preview:false) == nil
        }
        check("ETACS identity validates responder and requested identifier") {
            let good=CANFrame(ecu:"504",payload:[0x5A,0x87,4,0x82,0,0x17])
            return try BodyIdentityReply.decode([good],identifier:0x87).payloadHex == "5A8704820017" &&
                rejects{_=try BodyIdentityReply.decode([good],identifier:0x9C)} &&
                rejects{_=try BodyIdentityReply.decode([CANFrame(ecu:"7E8",payload:good.payload)],identifier:0x87)} &&
                rejects{_=try BodyIdentityReply.decode([good,good],identifier:0x87)} &&
                rejects{_=try BodyIdentityReply.decode([CANFrame(ecu:"504",payload:[0x7F,0x1A,0x22])],identifier:0x87)}
        }
        check("body identity only permits exact read-only route") {
            var route=DiagnosticRouteState()
            for c in ["ATCAF1","ATCFC1","ATSP6","ATSH620","ATCRA504","ATFCSH620","ATFCSD30080A","ATFCSM1"]{route.acknowledge(c)}
            return ReadPolicy.allowed("1A87",vehicle:true) && ReadPolicy.allowed("1A9C",vehicle:true) &&
                !ReadPolicy.allowed("1A90",vehicle:true) && !ReadPolicy.allowed("1092",vehicle:true) &&
                !ReadPolicy.allowed("21B0",vehicle:true) && route.canRead("1A87") &&
                !route.canRead("2101") && !ReadPolicy.allowedOnHeader("1A87",header:"7DF")
        }
        print("\(count-failures)/\(count) core tests passed")
        if failures > 0 { exit(1) }
    }
}
