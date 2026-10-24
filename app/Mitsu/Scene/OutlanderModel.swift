import RealityKit
import UIKit
import simd

/// Original procedural geometry utilities and the previous approximation.
/// Self-contained default for the public app; no downloaded vehicle mesh required.
@MainActor enum OutlanderModel {
    typealias V = SIMD3<Float>
    static func material(_ color:UIColor,metallic:Float=0,roughness:Float=0.5)->PhysicallyBasedMaterial {
        var m=PhysicallyBasedMaterial()
        m.baseColor = .init(tint:color);m.metallic = .init(floatLiteral:metallic);m.roughness = .init(floatLiteral:roughness)
        m.faceCulling = .none
        return m
    }
    static let paint:PhysicallyBasedMaterial = {
        var m=material(UIColor(red:0.018,green:0.022,blue:0.025,alpha:1),metallic:0.62,roughness:0.23)
        m.clearcoat = .init(floatLiteral:1);m.clearcoatRoughness = .init(floatLiteral:0.12)
        return m
    }()
    static let glass:PhysicallyBasedMaterial = {
        var m=material(UIColor(red:0.025,green:0.047,blue:0.056,alpha:1),metallic:0.22,roughness:0.09)
        m.clearcoat = .init(floatLiteral:1);m.clearcoatRoughness = .init(floatLiteral:0.065)
        return m
    }()
    static let rubber=material(UIColor(white:0.024,alpha:1),roughness:0.88)
    static let tread=material(UIColor(white:0.009,alpha:1),roughness:0.97)
    static let silver=material(UIColor(white:0.72,alpha:1),metallic:0.95,roughness:0.21)
    static let chrome=material(UIColor(white:0.90,alpha:1),metallic:1,roughness:0.11)
    static let black=material(UIColor(white:0.012,alpha:1),roughness:0.46)
    static let seam=material(UIColor(white:0.005,alpha:1),roughness:0.70)
    static let red=material(UIColor(red:0.38,green:0.006,blue:0.009,alpha:1),metallic:0.18,roughness:0.17)
    static func mesh(_ p:[V],_ indices:[UInt32],_ m:PhysicallyBasedMaterial,name:String)->ModelEntity {
        var descriptor=MeshDescriptor(name:name)
        descriptor.positions=MeshBuffers.Positions(p);descriptor.primitives = .triangles(indices)
        var n=Array(repeating:V.zero,count:p.count)
        for i in stride(from:0,to:indices.count,by:3){
            let a=Int(indices[i]),b=Int(indices[i+1]),c=Int(indices[i+2])
            let face=simd_cross(p[b]-p[a],p[c]-p[a]);n[a]+=face;n[b]+=face;n[c]+=face
        }
        descriptor.normals=MeshBuffers.Normals(n.map{simd_length_squared($0)>0.00000001 ? simd_normalize($0):V(0,1,0)})
        do{let e=ModelEntity(mesh:try MeshResource.generate(from:[descriptor]),materials:[m]);e.name=name;return e}
        catch{assertionFailure("Invalid authored surface: \(name)");return ModelEntity()}
    }
    static func surface(_ columns:Int,_ rows:Int,_ m:PhysicallyBasedMaterial,name:String,reverse:Bool=false,point:(Float,Float)->V)->ModelEntity {
        var p:[V]=[],i:[UInt32]=[]
        for row in 0...rows{for col in 0...columns{p.append(point(Float(col)/Float(columns),Float(row)/Float(rows)))}}
        for row in 0..<rows{for col in 0..<columns{
            let a=UInt32(row*(columns+1)+col),b=a+1,c=a+UInt32(columns+2),d=c-1
            i += reverse ? [a,c,b,a,d,c]:[a,b,c,a,c,d]
        }}
        return mesh(p,i,m,name:name)
    }
    static func quad(_ p:[V],_ m:PhysicallyBasedMaterial,name:String="panel")->ModelEntity{mesh(p,[0,1,2,0,2,3],m,name:name)}
    static func box(_ size:V,_ position:V,_ m:PhysicallyBasedMaterial,radius:Float=0.02)->ModelEntity{
        let e=ModelEntity(mesh:.generateBox(size:size,cornerRadius:radius),materials:[m]);e.position=position;return e
    }
    static func cylinder(radius:Float,height:Float,_ m:PhysicallyBasedMaterial)->ModelEntity{ModelEntity(mesh:.generateCylinder(height:height,radius:radius),materials:[m])}
    static func ball(_ size:V,_ position:V,_ m:PhysicallyBasedMaterial)->ModelEntity{
        let e=ModelEntity(mesh:.generateSphere(radius:1),materials:[m]);e.scale=size;e.position=position;return e
    }
    static func mix(_ a:V,_ b:V,_ t:Float)->V{a+(b-a)*t}
    static func curve(_ keys:[(Float,Float)],_ x:Float)->Float{
        if x<=keys[0].0{return keys[0].1};if x>=keys.last!.0{return keys.last!.1}
        let k=(0..<(keys.count-1)).first{keys[$0+1].0>=x}!
        let t=(x-keys[k].0)/(keys[k+1].0-keys[k].0)
        let p0=keys[max(0,k-1)].1,p1=keys[k].1,p2=keys[k+1].1,p3=keys[min(keys.count-1,k+2)].1
        return 0.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t)
    }
    static func tube(_ points:[V],radius:Float,_ m:PhysicallyBasedMaterial,name:String="trim")->ModelEntity{
        var vertices:[V]=[],indices:[UInt32]=[];let sides=8
        for j in points.indices{
            let tangent=simd_normalize(points[min(j+1,points.count-1)]-points[max(0,j-1)])
            let seed:V=abs(tangent.y)<0.9 ? [0,1,0]:[1,0,0]
            let a=simd_normalize(simd_cross(tangent,seed)),b=simd_cross(tangent,a)
            for k in 0...sides{let theta=Float(k)*2 * .pi/Float(sides);vertices.append(points[j]+radius*(a*cos(theta)+b*sin(theta)))}
        }
        for j in 0..<(points.count-1){for k in 0..<sides{let a=UInt32(j*(sides+1)+k),b=a+1,c=b+UInt32(sides+1),d=c-1;indices += [a,b,c,a,c,d]}}
        return mesh(vertices,indices,m,name:name)
    }
    static func line(_ a:V,_ b:V,radius:Float,_ m:PhysicallyBasedMaterial)->ModelEntity{tube([a,b],radius:radius,m)}
    static func width(_ z:Float)->Float{curve([(-2.327,0.68),(-2.13,0.84),(-1.75,0.89),(-0.8,0.90),(0.4,0.90),(1.5,0.895),(2.1,0.85),(2.327,0.73)],z)}
    static func shoulder(_ z:Float)->Float{curve([(-2.327,0.99),(-2.12,1.08),(-1.4,1.105),(-0.85,1.105),(0.5,1.115),(1.6,1.15),(2.327,1.085)],z)}
    static func sideX(_ y:Float,_ z:Float)->Float{
        let t=max(0,min(1,(y-0.31)/(shoulder(z)-0.31)))
        let profile=curve([(0,0.89),(0.18,0.96),(0.6,1),(0.83,0.997),(1,0.91)],t)
        let crease=0.006*exp(-pow((y-0.99)/0.025,2))
        return width(z)*profile+crease
    }
    static func lowerEdge(_ z:Float)->Float{
        var y:Float=0.31
        for center:Float in [-1.36,1.31]{let d=abs(z-center);if d<0.405{y=max(y,0.365+sqrt(max(0,0.405*0.405-d*d)))}}
        return y
    }
    static func cabinX(_ y:Float)->Float{0.846-(y-1.105)*0.245}
    static func make()->Entity{
        let car=Entity();car.name="Procedural Outlander-inspired illustration"
        // True wheel apertures: side strips terminate on each arch, rather than covering the tyres.
        for side:Float in [-1,1]{
            car.addChild(surface(220,20,paint,name:"Curved body and wheel arches",reverse:side>0){u,v in
                let z:Float = -1.97+4.02*u
                let bottom=lowerEdge(z),y=bottom+(shoulder(z)-bottom)*v
                return [side*sideX(y,z),y,z]
            })
            for center:Float in [-1.36,1.31]{
                let arc=(0...60).map{j->V in let a=Float(j) * .pi/60;let z=center+cos(a)*0.408,y=0.365+sin(a)*0.408;return [side*(sideX(y,z)+0.001),y,z]}
                car.addChild(tube(arc,radius:0.012,paint,name:"Rolled painted wheel arch"))
            }
        }
        car.addChild(box([1.48,0.095,3.95],[0,0.305,0.06],black,radius:0.04))
        // Crowned bonnet with shallow press lines and a rounded leading edge.
        car.addChild(surface(52,55,paint,name:"Sculpted bonnet",reverse:true){u,v in
            let z:Float = -2.255+1.335*v,x=(u*2-1)*width(z)*0.91
            let crown=0.038*(1-pow(abs(u*2-1),2))
            let press:Float = -0.009*exp(-pow((abs(u*2-1)-0.62)/0.045,2))*sin(v * .pi)
            return [x,shoulder(z)+crown+press,z]
        })
        // Roof, windshield and rear window all have compound curvature.
        car.addChild(surface(44,54,paint,name:"Compound curved roof",reverse:true){u,v in
            let z:Float = -0.30+1.91*v,x=(u*2-1)*0.714
            let y:Float = 1.625+0.028*sin(v * .pi)+0.025*(1-pow(u*2-1,2))
            return [x,y,z]
        })
        car.addChild(surface(44,24,glass,name:"Curved windscreen",reverse:true){u,v in
            let x=(u*2-1)*(0.798-0.086*v)
            return [x,1.135+0.49*v+0.018*sin(u * .pi)*sin(v * .pi),-0.955+0.655*v-0.035*sin(u * .pi)]
        })
        car.addChild(surface(32,22,glass,name:"Rear windscreen",reverse:true){u,v in
            let x=(u*2-1)*(0.712+0.098*v)
            return [x,1.635-0.48*v,1.61+0.62*v+0.025*sin(u * .pi)]
        })
        for side:Float in [-1,1]{
            let p:(Float,Float)->V={y,z in [side*self.cabinX(y),y,z]}
            car.addChild(surface(100,10,paint,name:"Cabin pillars",reverse:side>0){u,v in
                let z:Float = -0.955+3.185*u
                let top=curve([(-0.955,1.135),(-0.30,1.625),(0.3,1.655),(1.3,1.65),(1.61,1.625),(2.23,1.155)],z)
                let y:Float = 1.10+(top-1.10)*v
                return [side*cabinX(y),y,z]
            })
            let windows:[[V]]=[
                [p(1.137,-0.854),p(1.585,-0.267),p(1.604,0.285),p(1.142,0.285)],
                [p(1.143,0.366),p(1.606,0.366),p(1.584,1.122),p(1.159,1.122)],
                [p(1.163,1.205),p(1.575,1.205),p(1.548,1.495),p(1.185,1.982)]
            ]
            for (j,w) in windows.enumerated(){
                car.addChild(surface(22,12,glass,name:"Flush side glazing \(j)",reverse:side>0){u,v in
                    var pt=mix(mix(w[0],w[3],u),mix(w[1],w[2],u),v)
                    pt.x += side*(0.008+0.009*sin(u * .pi)*sin(v * .pi));return pt
                })
                car.addChild(tube(w+[w[0]],radius:0.009,black,name:"Rubber glazing seal"))
            }
            car.addChild(line(p(1.11,-0.90),p(1.635,-0.28),radius:0.025,paint))
            car.addChild(tube([p(1.115,-0.84),p(1.12,0.3),p(1.135,1.20),p(1.17,1.98)],radius:0.007,chrome,name:"Window lower chrome"))
            for z:Float in [0.325,1.16]{car.addChild(line(p(1.145,z),p(1.603,z),radius:0.023,black))}
            // Handles, subtly recessed door joins and the shoulder crease.
            for z:Float in [-0.02,0.97]{
                let x=side*(sideX(1.035,z)+0.012)
                car.addChild(ball([0.022,0.025,0.115],[x,1.035,z],seam))
                car.addChild(box([0.025,0.026,0.145],[x+side*0.014,1.039,z],paint,radius:0.012))
                car.addChild(box([0.026,0.006,0.085],[x+side*0.016,1.052,z],silver,radius:0.003))
            }
            for zs:[Float] in [[-0.86,-0.80,-0.72,-0.66],[0.325,0.33,0.34,0.35],[1.22,1.34,1.43,1.51]]{
                let ys:[Float]=[1.11,0.95,0.64,0.35]
                let points=zip(ys,zs).map{y,z in V(side*(sideX(y,z)+0.002),y,z)}
                car.addChild(tube(points,radius:0.0025,seam,name:"Panel shut line"))
            }
            car.addChild(tube([V(side*0.825,0.34,-0.88),V(side*0.873,0.34,0.15),V(side*0.85,0.34,0.88)],radius:0.018,black,name:"Sill cladding"))
            // Mirrors with painted caps, black lower housings and a slim indicator strip.
            car.addChild(box([0.15,0.055,0.10],[side*0.862,1.14,-0.69],black,radius:0.025))
            car.addChild(ball([0.135,0.078,0.128],[side*0.99,1.18,-0.68],paint))
            car.addChild(ball([0.134,0.033,0.127],[side*0.99,1.138,-0.68],black))
            car.addChild(box([0.006,0.013,0.16],[side*1.119,1.168,-0.70],silver,radius:0.005))
            car.addChild(ball([0.114,0.058,0.006],[side*0.99,1.183,-0.555],chrome))
            // Low-profile roof rails following the actual roof's sweep.
            let rail=(0...36).map{j->V in let t=Float(j)/36;return [side*0.64,1.674+0.018*sin(t * .pi),-0.18+1.68*t]}
            car.addChild(tube(rail,radius:0.016,silver,name:"Sculpted roof rail"))
            for z:Float in [-0.12,1.43]{car.addChild(box([0.045,0.033,0.09],[side*0.64,1.658,z],black,radius:0.01))}
        }
        front(car);rear(car)
        for side:Float in [-1,1]{for z:Float in [-1.36,1.31]{let w=wheel(side:side,z:z);w.name="wheel_"+(z<0 ? "F":"R")+(side<0 ? "L":"R");car.addChild(w)}}
        // Wipers sit on the screen, rather than floating on the bonnet.
        car.addChild(line([-0.65,1.148,-0.967],[-0.04,1.168,-0.96],radius:0.007,black))
        car.addChild(line([0.10,1.162,-0.97],[0.64,1.149,-0.966],radius:0.007,black))
        car.addChild(box([1.32,0.035,0.14],[0,1.656,1.61],paint,radius:0.014))
        car.addChild(line([0,1.655,1.16],[0,1.82,1.24],radius:0.006,black))
        return car
    }
    static func noseZ(_ x:Float)->Float{-2.327+0.19*pow(abs(x)/0.9,3)}
    static func frontPoint(_ x:Float,_ y:Float)->V{
        let t=max(0,min(1,(y-0.31)/0.785))
        return [x,y,noseZ(x)-0.020*sin(t * .pi)]
    }
    static func frontBlend(_ side:Float,_ u:Float,_ v:Float)->V{
        let start=frontPoint(side*0.867,0.31+0.785*v)
        let y:Float=0.31+(shoulder(-1.97)-0.31)*v
        let end=V(side*sideX(y,-1.97),y,-1.97)
        return mix(start,end,u)
    }
    static func frontPatch(_ car:Entity,x0:Float,x1:Float,y0:Float,y1:Float,_ m:PhysicallyBasedMaterial,name:String,depth:Float=0){
        car.addChild(surface(36,12,m,name:name,reverse:true){u,v in
            let x=x0+(x1-x0)*u,y=y0+(y1-y0)*v
            return frontPoint(x,y)+V(0,0,-depth)
        })
    }
    static func front(_ car:Entity){
        frontPatch(car,x0:-0.62,x1:0.62,y0:0.31,y1:0.465,paint,name:"Lower painted bumper")
        frontPatch(car,x0:-0.62,x1:0.62,y0:0.773,y1:1.065,paint,name:"Upper bumper bridge")
        for side:Float in [-1,1]{frontPatch(car,x0:side<0 ? -0.867:0.62,x1:side<0 ? -0.62:0.867,y0:0.31,y1:1.095,paint,name:"Rounded bumper corner")}
        frontPatch(car,x0:-0.615,x1:0.615,y0:0.465,y1:0.773,black,name:"Lower grille aperture")
        for y:Float in [0.51,0.57,0.63,0.69,0.75]{
            let points=(0...32).map{j->V in let x:Float = -0.60+1.20*Float(j)/32;return frontPoint(x,y)+V(0,0,-0.013)}
            car.addChild(tube(points,radius:0.012,black,name:"Horizontal grille louvre"))
        }
        frontPatch(car,x0:-0.405,x1:0.405,y0:0.94,y1:1.062,black,name:"Pre-facelift upper grille",depth:0.003)
        for side:Float in [-1,1]{
            // Wrap the bumper into the fender instead of leaving a thin open edge.
            car.addChild(surface(24,20,paint,name:"Bumper to front fender blend",reverse:side>0){u,v in frontBlend(side,u,v)})
            car.addChild(surface(24,12,paint,name:"Front fender upper closure",reverse:side<0){u,v in
                let outer=frontBlend(side,u,1),z=outer.z
                let inner=V(side*width(z)*0.91,shoulder(z),z)
                return mix(inner,outer,v)
            })
            for y:Float in [0.968,1.034]{
                let pts=(0...20).map{j->V in let x=side*(0.065+0.335*Float(j)/20);return frontPoint(x,y)+V(0,0,-0.028)}
                car.addChild(tube(pts,radius:0.011,chrome,name:"Twin chrome grille bar"))
            }
            let points:[V]=[frontPoint(side*0.421,0.944),frontPoint(side*0.856,0.987),frontPoint(side*0.849,1.095),frontPoint(side*0.437,1.063)]
            let center=points.reduce(V.zero,+)/4
            func lampPoint(_ u:Float,_ v:Float,_ depth:Float,_ inset:Float=1)->V{
                let p=mix(mix(points[0],points[1],u),mix(points[3],points[2],u),v)
                let xy=center+(p-center)*inset
                return frontPoint(xy.x,xy.y)+V(0,0,-depth)
            }
            car.addChild(surface(24,12,black,name:"Swept headlamp bezel",reverse:side>0){u,v in lampPoint(u,v,0.003)})
            car.addChild(surface(24,12,silver,name:"Headlamp continuous reflector shell",reverse:side>0){u,v in lampPoint(u,v,0.008,0.94)})
            // Three individual reflector bowls and fluted lens detailing.
            for (x,y,r):(Float,Float,Float) in [(0.50,1.006,0.048),(0.636,1.022,0.058),(0.776,1.043,0.038)]{
                let z=frontPoint(x,y).z-0.020
                let reflector=ball([r,r*0.76,0.014],[side*x,y,z],chrome);car.addChild(reflector)
                let center=ball([r*0.54,r*0.45,0.015],[side*x,y,z-0.008],silver);car.addChild(center)
                car.addChild(box([0.012,0.018,0.010],[side*x,y,z-0.026],material(UIColor(white:0.94,alpha:1)),radius:0.005))
            }
            var lens=material(UIColor(red:0.74,green:0.83,blue:0.88,alpha:1),metallic:0.08,roughness:0.08)
            lens.blending = .transparent(opacity:.init(floatLiteral:0.20));lens.clearcoat = .init(floatLiteral:1)
            car.addChild(surface(24,12,lens,name:"Clear swept headlamp cover",reverse:side>0){u,v in lampPoint(u,v,0.060)})
            let edge=(points+[points[0]]).map{$0+V(0,0,-0.010)}
            car.addChild(tube(edge,radius:0.004,chrome,name:"Headlamp polished surround"))
            for j in 0..<12{let x:Float = 0.45+Float(j)*0.032;car.addChild(line([side*x,0.958+(x-0.45)*0.09,noseZ(x)-0.032],[side*x,0.974+(x-0.45)*0.09,noseZ(x)-0.034],radius:0.002,silver))}
            let fog=ball([0.089,0.075,0.032],[side*0.735,0.525,noseZ(0.735)-0.028],black);car.addChild(fog)
            let bezel=cylinder(radius:0.060,height:0.012,chrome);bezel.orientation=simd_quatf(angle:.pi/2,axis:[1,0,0]);bezel.position=[side*0.735,0.525,noseZ(0.735)-0.057];car.addChild(bezel)
            car.addChild(ball([0.044,0.044,0.012],[side*0.735,0.525,noseZ(0.735)-0.067],silver))
        }
        emblem(car,position:[0,1.007,-2.366],scale:0.026)
        car.addChild(box([0.47,0.105,0.024],[0,0.59,-2.377],black,radius:0.006))
        car.addChild(box([0.435,0.085,0.006],[0,0.59,-2.392],material(UIColor(white:0.69,alpha:1)),radius:0.004))
        car.addChild(line([-0.71,0.35,-2.23],[0.71,0.35,-2.23],radius:0.019,black))
    }
    static func rearPoint(_ u:Float,_ v:Float)->V{
        let x=(u*2-1)*(0.75+0.08*sin(v * .pi)),y:Float=0.31+0.845*v
        return [x,y,2.28+0.047*sin(u * .pi)-0.03*sin(v * .pi)]
    }
    static func rearCorner(_ side:Float,_ u:Float,_ v:Float)->V{
        let y:Float=0.31+(shoulder(2.05)-0.31)*v
        let start=V(side*sideX(y,2.05),y,2.05)
        let end=rearPoint(side>0 ? 1:0,v)
        return mix(start,end,u)
    }
    static func rear(_ car:Entity){
        car.addChild(surface(40,8,paint,name:"Tailgate shoulder connection",reverse:true){u,v in
            let window=V((u*2-1)*0.81,1.155,2.23+0.025*sin(u * .pi))
            return mix(window,rearPoint(u,1),v)
        })
        for side:Float in [-1,1]{
            car.addChild(surface(20,24,paint,name:"Wrapped rear bumper and corner",reverse:side>0){u,v in
                rearCorner(side,u,v)
            })
        }
        car.addChild(surface(48,30,paint,name:"Rounded tailgate"){u,v in rearPoint(u,v)})
        car.addChild(tube((0...40).map{j in rearPoint(Float(j)/40,0.968)+V(0,0,0.007)},radius:0.007,chrome,name:"Tailgate chrome belt"))
        for side:Float in [-1,1]{
            car.addChild(surface(24,10,red,name:"Inset rear lamp face"){u,v in
                let t:Float=side>0 ? 0.76+0.24*u:0.24*u
                return rearPoint(t,0.835+0.145*v)+V(0,0,0.003)
            })
            car.addChild(surface(18,10,red,name:"Wrapped rear lamp side",reverse:side>0){u,v in
                rearCorner(side,0.25+0.75*u,0.835+0.145*v)+V(side*0.003,0,0.003)
            })
            car.addChild(surface(20,3,silver,name:"Rear reversing lens"){u,v in
                let t:Float=side>0 ? 0.79+0.18*u:0.03+0.18*u
                return rearPoint(t,0.895+0.024*v)+V(0,0,0.005)
            })
            car.addChild(box([0.12,0.025,0.025],[side*0.64,0.43,2.30],red,radius:0.008))
        }
        car.addChild(box([0.43,0.115,0.019],[0,0.90,2.341],black,radius:0.007))
        car.addChild(box([1.40,0.09,0.09],[0,0.34,2.15],black,radius:0.035))
        car.addChild(line([-0.34,1.32,1.98],[0.18,1.34,1.96],radius:0.007,black))
        emblem(car,position:[0,1.075,2.35],scale:0.021,back:true)
    }
    static func emblem(_ parent:Entity,position:V,scale:Float,back:Bool=false){
        for a:Float in [0,2 * .pi/3,4 * .pi/3]{
            let pts:[V]=[[0,0,0],[0.5,0.866,0],[0,1.732,0],[-0.5,0.866,0]]
            let d=quad(pts.map{$0*scale},chrome,name:"Mitsubishi diamond")
            d.position=position;d.orientation=simd_quatf(angle:a,axis:[0,0,1]);if back{d.orientation=simd_quatf(angle:.pi,axis:[0,1,0])*d.orientation};parent.addChild(d)
        }
    }
    /// Surface of revolution around the X axle. Profiles are axial/radial pairs.
    static func lathe(_ profile:[SIMD2<Float>],segments:Int=72,_ m:PhysicallyBasedMaterial,name:String)->ModelEntity{
        var p:[V]=[],indices:[UInt32]=[]
        for j in 0...segments{let a=Float(j)*2 * .pi/Float(segments);for v in profile{p.append([v.x,sin(a)*v.y,cos(a)*v.y])}}
        for j in 0..<segments{for k in 0..<(profile.count-1){let a=UInt32(j*profile.count+k),b=a+1,c=b+UInt32(profile.count),d=c-1;indices += [a,b,c,a,c,d]}}
        return mesh(p,indices,m,name:name)
    }
    static func wheel(side:Float,z:Float)->Entity{
        let wheel=Entity();wheel.name="wheel";wheel.position=[side*0.787,0.365,z]
        let tyre:[SIMD2<Float>]=[[-0.10,0.238],[-0.117,0.272],[-0.115,0.316],[-0.092,0.347],[-0.055,0.361],[0.055,0.361],[0.092,0.347],[0.115,0.316],[0.117,0.272],[0.10,0.238]]
        wheel.addChild(lathe(tyre.map{[side*$0.x,$0.y]},rubber,name:"Rounded 225/55 tyre"))
        let rim:[SIMD2<Float>]=[[0.083,0.225],[0.116,0.230],[0.127,0.225],[0.120,0.215],[0.071,0.210],[0.064,0.075],[0.097,0.055]]
        wheel.addChild(lathe(rim.map{[side*$0.x,$0.y]},silver,name:"Deep alloy barrel"))
        let disc=cylinder(radius:0.187,height:0.013,material(UIColor(white:0.22,alpha:1),metallic:0.86,roughness:0.43));disc.orientation=simd_quatf(angle:.pi/2,axis:[0,0,1]);disc.position.x=side*0.066;wheel.addChild(disc)
        wheel.addChild(box([0.045,0.11,0.05],[side*0.078,0.05,-0.14],material(UIColor(white:0.12,alpha:1),metallic:0.65),radius:0.015))
        for i in 0..<10{
            let angle=Float(i/2)*2 * .pi/5+(i%2==0 ? -0.115:0.115)
            var p:[V]=[]
            for axle:Float in [0.086,0.122]{for (r,a):(Float,Float) in [(0.055,angle-0.14),(0.224,angle-0.04),(0.224,angle+0.04),(0.055,angle+0.14)]{p.append([side*axle,sin(a)*r,cos(a)*r])}}
            wheel.addChild(mesh(p,[0,1,2,0,2,3,4,6,5,4,7,6,0,4,5,0,5,1,1,5,6,1,6,2,2,6,7,2,7,3,3,7,4,3,4,0],silver,name:"Split cast alloy spoke"))
        }
        let hub=cylinder(radius:0.053,height:0.014,silver);hub.orientation=disc.orientation;hub.position.x=side*0.130;wheel.addChild(hub)
        for i in 0..<5{let a=Float(i)*2 * .pi/5;wheel.addChild(ball([0.006,0.009,0.009],[side*0.141,sin(a)*0.038,cos(a)*0.038],black))}
        // Consolidated tread channels: circumferential grooves plus diagonal sipes.
        for x:Float in [-0.047,0,0.047]{wheel.addChild(lathe([[side*(x-0.002),0.3614],[side*(x+0.002),0.3614]],tread,name:"Tyre circumferential groove"))}
        var p:[V]=[],indices:[UInt32]=[]
        for i in 0..<84{for band in 0..<4{
            let a=Float(i)*2 * .pi/84,x:Float = -0.082+Float(band)*0.041
            let start=UInt32(p.count)
            for (dx,da):(Float,Float) in [(0,-0.004),(0,0.004),(0.032,0.025),(0.032,0.017)]{let angle=a+da;p.append([side*(x+dx),sin(angle)*0.3617,cos(angle)*0.3617])}
            indices += [start,start+1,start+2,start,start+2,start+3]
        }}
        wheel.addChild(mesh(p,indices,tread,name:"Tyre tread sipes"))
        return wheel
    }
}
