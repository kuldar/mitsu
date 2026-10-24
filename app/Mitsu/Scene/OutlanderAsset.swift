import RealityKit
import Foundation

/// Original procedural illustration, or an optional locally supplied licensed USDZ.
/// Meshes and textures are shared across scene instances; loading never blocks UI.
@MainActor enum OutlanderAsset {
    private static var pending:Task<Entity,Error>?
    private static var prototype:Entity?

    static var hasCustomModel:Bool{Bundle.main.url(forResource:"Outlander2014",withExtension:"usdz") != nil}
    static var readyDescription:String{"Vehicle model ready · "+(hasCustomModel ? "Custom vehicle asset":"Procedural car illustration")}
    static func load() async throws -> Entity {
        if let prototype {return prototype.clone(recursive:true)}
        if !hasCustomModel {
            let generated=OutlanderModel.make()
            prototype=generated
            return generated.clone(recursive:true)
        }
        if pending == nil {
            pending=Task {
                guard let url=Bundle.main.url(forResource:"Outlander2014",withExtension:"usdz") else {
                    throw CocoaError(.fileNoSuchFile)
                }
                return try await Entity(contentsOf:url)
            }
        }
        do {
            let loaded=try await pending!.value
            prototype=loaded
            pending=nil
            return loaded.clone(recursive:true)
        } catch {
            pending=nil
            throw error
        }
    }
}
