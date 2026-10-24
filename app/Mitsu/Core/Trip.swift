import Foundation

struct TripRecord: Codable, Identifiable {
    var id = UUID()
    var started: Date
    var ended: Date
    var distanceKM: Double
    var coveredSeconds: Double
    var duration: Double { max(0, ended.timeIntervalSince(started)) }
    var coverage: Double { duration > 0 ? min(1, coveredSeconds / duration) : 0 }
}

struct TripAccumulator {
    private(set) var distanceKM = 0.0
    private(set) var coveredSeconds = 0.0
    private var previous: Sample?
    mutating func accept(_ sample: Sample) {
        guard sample.signal == .speed else { return }
        guard sample.source == .live, sample.value.isFinite,
              sample.value >= 0, sample.value <= 300, sample.uptime.isFinite else { previous = nil; return }
        defer { previous = sample }
        guard let previous else { return }
        let dt = sample.uptime - previous.uptime
        guard dt > 0, dt <= 3 else { return }
        distanceKM += (previous.value+sample.value)/2*dt/3600
        coveredSeconds += dt
    }
    mutating func interrupt() { previous = nil }
}
