import Foundation

enum Signal: String, Codable, CaseIterable {
    case speed, rpm, coolant, load, airflow, throttle, intake, voltage, supply, steering
    var title: String {
        switch self {
        case .speed: return "Speed"
        case .rpm: return "Engine speed"
        case .coolant: return "Coolant"
        case .load: return "Engine load"
        case .airflow: return "Airflow"
        case .throttle: return "Throttle"
        case .intake: return "Intake air"
        case .voltage: return "ECU voltage"
        case .supply: return "Adapter voltage"
        case .steering: return "Steering wheel"
        }
    }
    var unit: String {
        switch self {
        case .speed: return "km/h"
        case .rpm: return "rpm"
        case .coolant, .intake: return "°C"
        case .load, .throttle: return "%"
        case .airflow: return "g/s"
        case .voltage, .supply: return "V"
        case .steering: return "°"
        }
    }
    var lifetime: TimeInterval { [.speed, .rpm, .steering].contains(self) ? 3 : 20 }
    var pid: UInt8? {
        switch self {
        case .speed: return 0x0D
        case .rpm: return 0x0C
        case .coolant: return 0x05
        case .load: return 0x04
        case .airflow: return 0x10
        case .throttle: return 0x11
        case .intake: return 0x0F
        case .voltage: return 0x42
        default: return nil
        }
    }
    var decimals: Int { [.voltage, .supply, .airflow].contains(self) ? 1 : 0 }
}

enum SampleSource: String, Codable { case live, preview, replay
    var permitsVehicleConnection:Bool{self == .live}
}

struct Sample: Codable, Equatable {
    let signal: Signal
    let value: Double
    let ecu: String
    let uptime: TimeInterval
    let source: SampleSource
    func isFresh(at now: TimeInterval) -> Bool {
        value.isFinite && now.isFinite && uptime.isFinite && now >= uptime && now - uptime <= signal.lifetime
    }
}

struct VehicleSnapshot {
    var samples: [Signal: Sample] = [:]
    func value(_ signal: Signal, at now: TimeInterval, connected: Bool, preview: Bool) -> Double? {
        guard let sample = samples[signal], sample.isFresh(at: now),
              preview ? sample.source == .preview : (connected && sample.source == .live) else { return nil }
        return sample.value
    }
}
