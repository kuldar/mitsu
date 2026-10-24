import RealityKit
import UIKit
import simd
import SwiftUI

/// A local, fading ground illustration. HDR maps illuminate the car but are never
/// displayed as sky or scenery. Rendering needs no GPS or network connection.
@MainActor final class RoadsideEnvironment {
    let root=Entity()
    let lighting:EnvironmentResource
    private var precipitation:ModelEntity?
    private var precipitationMaterial:CustomMaterial?
    private var elapsed:Float=0
    private var playing=false

    init(dark:Bool,weather:WeatherKind)async throws {
        let overcast=[WeatherKind.cloud,.rain,.snow,.fog].contains(weather)
        let lightName=dark && !overcast ? "night":overcast ? "overcast":"clear"
        lighting=try await OutdoorAssets.lighting(lightName)
        let mode:Float=switch weather{case .neutral,.clear:0;case .cloud:1;case .rain:2;case .snow:3;case .fog:4}
        let config=SIMD4<Float>(mode,dark ? 1:0,0,0)
        var asphalt=try OutdoorAssets.shader("mitsuOutdoorGround")
        asphalt.baseColor.texture = .init(try await OutdoorAssets.texture("asphalt_02_Diffuse"))
        asphalt.normal.texture = .init(try await OutdoorAssets.texture("asphalt_02_nor_gl",normal:true))
        asphalt.roughness.texture = .init(try await OutdoorAssets.texture("asphalt_02_Rough",raw:true))
        asphalt.custom.value=config
        root.addChild(Self.plane(width:7.4,depth:18,at:[1.65,-0.012,0],asphalt))
        var grass=asphalt
        grass.baseColor.texture = .init(try await OutdoorAssets.texture("grass_Diffuse"))
        grass.normal.texture = .init(try await OutdoorAssets.texture("grass_nor_gl",normal:true))
        grass.custom.value.w=1
        // Disjoint ground patches avoid grass appearing through fading asphalt.
        root.addChild(Self.plane(width:6,depth:18,at:[-5.70,-0.04,0],grass))
        root.addChild(Self.plane(width:6,depth:18,at:[8.98,-0.04,0],grass))
        var gravel=asphalt;gravel.custom.value.w=2
        for x:Float in [-2.35,5.65]{root.addChild(Self.plane(width:0.65,depth:18,at:[x,-0.018,0],gravel))}
        var paint=asphalt;paint.custom.value.w=3
        for x:Float in [-1.83,5.13]{root.addChild(Self.plane(width:0.12,depth:18,at:[x,-0.008,0],paint))}
        for z:Float in [-9,0,9]{root.addChild(Self.plane(width:0.12,depth:3,at:[1.65,-0.007,z],paint))}
        var contact=try OutdoorAssets.shader("mitsuContactShadow",unlit:true)
        contact.blending = .transparent(opacity:.init(floatLiteral:1))
        root.addChild(Self.plane(width:2.3,depth:4.6,at:[0,-0.005,0],contact))
        let mask=try await LocalSceneMask.texture()
        // An opaque, flat-colour backdrop uses the same colour pipeline as the
        // canvas fade. No sky texture is visible, even when orbiting the car.
        var backdrop=UnlitMaterial(color:UIColor(Palette(dark:dark).canvas),applyPostProcessToneMap:false)
        backdrop.faceCulling = .front
        let shell=ModelEntity(mesh:.generateSphere(radius:45),materials:[backdrop])
        shell.components.set(DynamicLightShadowComponent(castsShadow:false))
        shell.components.set(GroundingShadowComponent(castsShadow:false))
        root.addChild(shell)
        var canvas=UnlitMaterial(color:UIColor(Palette(dark:dark).canvas),applyPostProcessToneMap:false)
        canvas.blending = .transparent(opacity:.init(scale:1,texture:.init(mask)))
        canvas.writesDepth=false;canvas.readsDepth=true
        root.addChild(Self.plane(width:LocalSceneMask.width,depth:LocalSceneMask.depth,at:[0,-0.002,0],canvas))
        if weather == .rain || weather == .snow{try addPrecipitation(snow:weather == .snow,dark:dark,mask:mask)}
    }
    func setAnimating(_ value:Bool){playing=value}
    func advance(_ dt:Float){
        guard playing,let entity=precipitation,var material=precipitationMaterial else{return}
        elapsed += min(max(0,dt),0.05)
        material.custom.value.x=elapsed
        entity.model?.materials=[material]
        precipitationMaterial=material
    }
    private static func plane(width:Float,depth:Float,at position:SIMD3<Float>,_ material:any RealityKit.Material)->ModelEntity {
        let e=ModelEntity(mesh:.generatePlane(width:width,depth:depth),materials:[material]);e.position=position;return e
    }
    private func addPrecipitation(snow:Bool,dark:Bool,mask:TextureResource)throws {
        guard let library=OutdoorAssets.library else{throw CocoaError(.featureUnsupported)}
        var material=try CustomMaterial(surfaceShader:.init(named:"mitsuLocalPrecipitation",in:library),geometryModifier:.init(named:"mitsuLocalPrecipitationMotion",in:library),lightingModel:.unlit)
        material.custom.value=[0,snow ? 1:0,dark ? 1:0,0]
        material.custom.texture = .init(mask)
        material.blending = .transparent(opacity:.init(floatLiteral:1))
        material.faceCulling = .none
        var positions:[SIMD3<Float>]=[],normals:[SIMD3<Float>]=[],uv:[SIMD2<Float>]=[],indices:[UInt32]=[]
        let count=snow ? 150:280
        for i in 0..<count {
            let x=(Float((i*37)%101)/100*10-5)*10
            let z=(Float((i*73)%139)/138*13.6-6.8)*10
            let center=SIMD3<Float>(x.rounded()/10,Float((i*17)%127)/126*3.7+0.04,z.rounded()/10)
            let a=UInt32(positions.count)
            // Original geometry encloses the entire animated volume for culling.
            positions += [center+[-0.02,-0.04,0],center+[0.02,-0.04,0],center+[0.02,0.04,0],center+[-0.02,0.04,0]]
            normals += Array(repeating:[0,0,1],count:4)
            uv += [[0,0],[1,0],[1,1],[0,1]];indices += [a,a+1,a+2,a,a+2,a+3]
        }
        var descriptor=MeshDescriptor(name:snow ? "Local drifting snow":"Local fine rain")
        descriptor.positions=MeshBuffers.Positions(positions);descriptor.normals=MeshBuffers.Normals(normals)
        descriptor.textureCoordinates=MeshBuffers.TextureCoordinates(uv);descriptor.primitives = .triangles(indices)
        let entity=ModelEntity(mesh:try MeshResource.generate(from:[descriptor]),materials:[material])
        entity.name="Precipitation with the same ground fade"
        root.addChild(entity);precipitation=entity;precipitationMaterial=material
    }
}
