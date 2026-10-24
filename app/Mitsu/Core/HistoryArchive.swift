import Foundation

enum HistoryArchive {
    /// A decode error must never let a subsequent save destroy the only copy.
    static func load(from file:URL) throws -> [TripRecord] {
        guard FileManager.default.fileExists(atPath:file.path) else{return []}
        let data=try Data(contentsOf:file)
        do{return try JSONDecoder().decode([TripRecord].self,from:data)}
        catch{
            let backup=file.deletingPathExtension().appendingPathExtension("unreadable-\(UUID().uuidString).json")
            try data.write(to:backup,options:.atomic)
            throw DiagnosticError.invalid("Saved journeys could not be read. An original copy was preserved beside the history file.")
        }
    }
}
