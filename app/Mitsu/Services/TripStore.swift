import Foundation

@MainActor final class TripStore: ObservableObject {
    @Published private(set) var records:[TripRecord]=[]
    @Published private(set) var active=false
    @Published private(set) var accumulator=TripAccumulator()
    @Published private(set) var started:Date?
    @Published private(set) var errorMessage:String?
    private let file:URL
    private var storageWritable=true
    init() {
        let directory=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
        file=directory.appendingPathComponent("journeys.json")
        do{records=try HistoryArchive.load(from:file)}catch{storageWritable=false;errorMessage=error.localizedDescription+" History writes are paused to preserve your data."}
    }
    func begin() { guard !active else{return}; accumulator=TripAccumulator(); started=Date(); active=true }
    func accept(_ sample:Sample) { guard active else{return}; accumulator.accept(sample) }
    func end() {
        guard active,let started else{return}; active=false
        records.insert(TripRecord(started:started,ended:Date(),distanceKM:accumulator.distanceKM,coveredSeconds:accumulator.coveredSeconds),at:0)
        save()
    }
    func delete(_ id:UUID) { records.removeAll{$0.id==id}; save() }
    func deleteAll() { records=[]; save() }
    private func save() {
        guard storageWritable else{errorMessage="History writes are paused because the original file could not be read. Your original data has not been overwritten.";return}
        do { try JSONEncoder().encode(records).write(to:file,options:[.atomic,.completeFileProtection]) }
        catch { errorMessage="Journey could not be saved on this iPad." }
    }
    var exportText:String {
        let f=ISO8601DateFormatter()
        return "started,ended,distance_km,covered_seconds\n"+records.map{"\(f.string(from:$0.started)),\(f.string(from:$0.ended)),\($0.distanceKM),\($0.coveredSeconds)"}.joined(separator:"\n")
    }
}
