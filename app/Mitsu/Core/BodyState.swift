import Foundation

enum BodySignal:String,CaseIterable,Codable {
    case lowBeam,highBeam,positionLights,frontFog,rearFog,indicatorLeft,indicatorRight
    case doorFL,doorFR,doorRL,doorRR,tailgate,brake,reverse,wipers
    var title:String {
        switch self {
        case .lowBeam:return "Dipped headlights"
        case .highBeam:return "High beams"
        case .positionLights:return "Position & tail lights"
        case .frontFog:return "Front fog lights"
        case .rearFog:return "Rear fog lights"
        case .indicatorLeft:return "Left indicator"
        case .indicatorRight:return "Right indicator"
        case .doorFL:return "Front left door"
        case .doorFR:return "Front right door"
        case .doorRL:return "Rear left door"
        case .doorRR:return "Rear right door"
        case .tailgate:return "Tailgate"
        case .brake:return "Brake lights"
        case .reverse:return "Reverse lights"
        case .wipers:return "Wipers"
        }
    }
    var isDoor:Bool{[Self.doorFL,.doorFR,.doorRL,.doorRR,.tailgate].contains(self)}
}

struct BodySample:Equatable {
    let value:Bool
    let uptime:TimeInterval
    let source:SampleSource
}

struct BodySnapshot {
    var samples:[BodySignal:BodySample]=[:]
    func value(_ signal:BodySignal,at now:TimeInterval,connected:Bool,preview:Bool)->Bool? {
        guard let sample=samples[signal],now.isFinite,sample.uptime.isFinite,
              now>=sample.uptime,now-sample.uptime<=3,
              preview ? sample.source == .preview : (connected && sample.source == .live) else{return nil}
        return sample.value
    }
}

/// A diagnostic identity reply establishes reachability only, never lamp/door state.
struct BodyIdentityReply:Codable,Equatable {
    let request:String
    let responder:String
    let payloadHex:String
    static func decode(_ frames:[CANFrame],identifier:UInt8)throws->Self {
        guard [UInt8(0x87),0x9C].contains(identifier),frames.count==1,let frame=frames.first,
              frame.ecu=="504",(3...128).contains(frame.payload.count),
              frame.payload.prefix(2)==[0x5A,identifier] else {
            throw DiagnosticError.invalid("Body controller did not return a matching identity reply")
        }
        return Self(request:String(format:"1A%02X",identifier),responder:frame.ecu,
                    payloadHex:frame.payload.map{String(format:"%02X",$0)}.joined())
    }
}

struct BodyIdentityReport:Codable {
    let started:Date
    var replies:[BodyIdentityReply]=[]
    var attempts:[Attempt]=[]
    var outcome="Checking"
    let note="Identity only; no live body states or vehicle settings validated. No VIN request."
    struct Attempt:Codable {let request:String;let reply:String}
    func export(to folder:URL)throws->URL {
        let file=folder.appendingPathComponent("Mitsu-body-controller.json")
        let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys];encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(self).write(to:file,options:.atomic)
        return file
    }
}
