import CoreGraphics
import Foundation
import RealityKit

/// An original HDR studio reflection map generated from light shapes, with no external assets.
@MainActor enum StudioEnvironment {
    static let resource:EnvironmentResource? = make()
    private static func make()->EnvironmentResource? {
        let width=512,height=256
        var pixels=[Float](repeating:0,count:width*height*4)
        func softbox(_ x:Float,_ y:Float,cx:Float,cy:Float,wx:Float,wy:Float)->Float{
            let dx=min(abs(x-cx),1-abs(x-cx))/wx,dy=abs(y-cy)/wy
            return exp(-pow(dx,8)-pow(dy,8))
        }
        for y in 0..<height{for x in 0..<width{
            let u=Float(x)/Float(width),v=Float(y)/Float(height)
            let ambient:Float = 0.08+0.18*max(0,1-v)
            let key=softbox(u,v,cx:0.18,cy:0.31,wx:0.07,wy:0.10)*2.8
            let strip=softbox(u,v,cx:0.67,cy:0.35,wx:0.020,wy:0.20)*2.0
            let ceiling=softbox(u,v,cx:0.47,cy:0.12,wx:0.12,wy:0.018)*1.7
            let fill=softbox(u,v,cx:0.91,cy:0.43,wx:0.10,wy:0.11)*0.5
            let i=(y*width+x)*4
            pixels[i]=ambient+key+strip*0.92+ceiling+fill*0.88
            pixels[i+1]=ambient+key*0.98+strip*0.97+ceiling+fill*0.95
            pixels[i+2]=ambient+key*0.94+strip+ceiling+fill
            pixels[i+3]=1
        }}
        let data=pixels.withUnsafeBufferPointer{Data(buffer:$0)}
        guard let provider=CGDataProvider(data:data as CFData),let space=CGColorSpace(name:CGColorSpace.extendedLinearSRGB),
              let image=CGImage(width:width,height:height,bitsPerComponent:32,bitsPerPixel:128,bytesPerRow:width*16,space:space,bitmapInfo:[.floatComponents,.byteOrder32Little,CGBitmapInfo(rawValue:CGImageAlphaInfo.noneSkipLast.rawValue)],provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent) else{return nil}
        return try? EnvironmentResource(equirectangular:image,withName:"Mitsu original softbox environment")
    }
}
