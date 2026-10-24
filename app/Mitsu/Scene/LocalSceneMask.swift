import RealityKit
import CoreGraphics
import Foundation

/// One shared coverage map for background compositing and precipitation.
/// The ground stays physically lit; an unlit canvas layer blends its outer edge
/// after lighting, so highlights cannot turn the fade white.
@MainActor enum LocalSceneMask {
    static let width:Float=30
    static let depth:Float=24
    private static var cached:TextureResource?
    static func texture()async throws->TextureResource {
        if let cached{return cached}
        let size=512
        var pixels=[UInt8](repeating:0,count:size*size*4)
        for y in 0..<size{for x in 0..<size{
            let worldX=(Float(x)/Float(size-1)-0.5)*width
            let worldZ=(Float(y)/Float(size-1)-0.5)*depth
            let radius=sqrt(pow(worldX/2.65,2)+pow(worldZ/3.65,2))
            let t=min(1,max(0,(radius-0.94)/(1.62-0.94)))
            // Ground ends before this outer margin. Dissolve the canvas plane's
            // own edge too, avoiding an antialiased outline against the backdrop.
            let edge=min(width/2-abs(worldX),depth/2-abs(worldZ))
            let outer=min(1,max(0,edge/0.6))
            let alpha=UInt8((t*t*(3-2*t)*outer*outer*(3-2*outer)*255).rounded())
            let i=(y*size+x)*4
            // Linear scalar data, separate from the canvas colour. Keeping the
            // image opaque avoids colour/alpha unpremultiplication fringes.
            pixels[i]=alpha;pixels[i+1]=alpha;pixels[i+2]=alpha;pixels[i+3]=255
        }}
        let data=Data(pixels)
        guard let provider=CGDataProvider(data:data as CFData),
              let image=CGImage(width:size,height:size,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:size*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent) else {throw CocoaError(.fileReadCorruptFile)}
        let texture=try await TextureResource(image:image,withName:"Shared local surroundings fade",options:.init(semantic:.raw))
        cached=texture;return texture
    }
}
