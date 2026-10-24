import RealityKit
import ImageIO
import Metal

/// Bundled photographic assets; cached GPU resources, no network required.
@MainActor enum OutdoorAssets {
    private static var textures:[String:TextureResource]=[:]
    private static var lights:[String:EnvironmentResource]=[:]
    static let library=MTLCreateSystemDefaultDevice()?.makeDefaultLibrary()

    static func url(_ name:String,_ ext:String)throws -> URL {
        guard let url=Bundle.main.url(forResource:name,withExtension:ext,subdirectory:"Environment") ?? Bundle.main.url(forResource:name,withExtension:ext) else {throw CocoaError(.fileNoSuchFile)}
        return url
    }
    static func texture(_ name:String,normal:Bool=false,raw:Bool=false)async throws->TextureResource {
        if let t=textures[name]{return t}
        let t=try await TextureResource(contentsOf:url(name,"jpg"),options:.init(semantic:normal ? .normal:raw ? .raw:.color))
        textures[name]=t;return t
    }
    static func lighting(_ name:String)async throws->EnvironmentResource {
        if let e=lights[name]{return e}
        let url=try url(name,"hdr")
        let image=try await Task.detached(priority:.userInitiated){
            guard let source=CGImageSourceCreateWithURL(url as CFURL,nil),let image=CGImageSourceCreateImageAtIndex(source,0,[kCGImageSourceShouldCacheImmediately:true] as CFDictionary) else{throw CocoaError(.fileReadCorruptFile)}
            return image
        }.value
        let resource=try await EnvironmentResource(equirectangular:image,withName:"Mitsu outdoor "+name)
        lights[name]=resource;return resource
    }
    static func shader(_ name:String,unlit:Bool=false)throws->CustomMaterial {
        guard let library else{throw CocoaError(.featureUnsupported)}
        return try CustomMaterial(surfaceShader:.init(named:name,in:library),lightingModel:unlit ? .unlit:.clearcoat)
    }
}
