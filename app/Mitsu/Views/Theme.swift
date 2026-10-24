import SwiftUI

struct Palette {
    let dark:Bool
    var canvas:Color{Color(hex:dark ? 0x0C1015:0xF1F3F4)}
    var surface:Color{Color(hex:dark ? 0x161D25:0xFFFFFF)}
    var inset:Color{Color(hex:dark ? 0x202B35:0xE4E9EC)}
    var ink:Color{Color(hex:dark ? 0xEAF0F5:0x19252F)}
    var muted:Color{Color(hex:dark ? 0x9BA9B8:0x64727F)}
    var line:Color{ink.opacity(dark ? 0.12:0.11)}
    var accent:Color{Color(hex:0xA5E4ED)}
    var accentInk:Color{Color(hex:dark ? 0xA5E4ED:0x286B7A)}
    var positive:Color{Color(hex:dark ? 0x8FC7AC:0x467C65)}
}

extension Color {
    init(hex:UInt32){self.init(.sRGB,red:Double((hex>>16)&255)/255,green:Double((hex>>8)&255)/255,blue:Double(hex&255)/255,opacity:1)}
}

struct Eyebrow:View {
    var text:String
    var body:some View{Text(text.uppercased()).font(.system(size:10,weight:.semibold)).tracking(1.6)}
}

struct MitsuMark:Shape {
    func path(in rect:CGRect)->Path{
        var path=Path();let scale=min(rect.width,rect.height)/36;let center=CGPoint(x:rect.midX,y:rect.midY+3*scale)
        for angle in [0.0,2*Double.pi/3,4*Double.pi/3]{
            let points=[CGPoint(x:0,y:0),CGPoint(x:6,y:-10.392),CGPoint(x:0,y:-20.784),CGPoint(x:-6,y:-10.392)]
            let transformed=points.map{CGPoint(x:center.x+($0.x*cos(angle)-$0.y*sin(angle))*scale,y:center.y+($0.x*sin(angle)+$0.y*cos(angle))*scale)}
            path.addLines(transformed);path.closeSubpath()
        };return path
    }
}

struct ConsolePressStyle:ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration:Configuration)->some View{
        configuration.label.frame(minWidth:44,minHeight:44).contentShape(Rectangle())
            .opacity(!enabled ? 0.35:configuration.isPressed ? 0.65:1)
            .scaleEffect(configuration.isPressed && !reducedMotion ? 0.975:1)
            .animation(reducedMotion ? nil:.easeOut(duration:0.16),value:configuration.isPressed)
    }
}

struct ConsoleRule:View {
    var palette:Palette
    var body:some View{Rectangle().fill(palette.line).frame(height:1).accessibilityHidden(true)}
}

struct SectionHeading:View {
    var title:String
    var subtitle:String?=nil
    var palette:Palette
    var body:some View{
        VStack(alignment:.leading,spacing:7){
            Text(title).font(.system(size:23,weight:.medium)).tracking(-0.5)
            if let subtitle{Text(subtitle).font(.system(size:13)).foregroundStyle(palette.muted).fixedSize(horizontal:false,vertical:true)}
        }
    }
}

struct StatusPill:View {
    var text:String
    var color:Color
    var body:some View{
        HStack(spacing:6){Circle().fill(color).frame(width:5,height:5);Text(text).font(.system(size:11,weight:.medium)).lineLimit(1)}
            .foregroundStyle(color).padding(.horizontal,10).frame(height:28).background(color.opacity(0.09),in:Capsule())
    }
}

// Retained for occasional floating sheets; everyday instruments use open layouts.
struct Panel<Content:View>:View {
    var palette:Palette
    var padding:CGFloat=24
    @ViewBuilder var content:Content
    var body:some View{content.padding(padding).background(palette.surface,in:RoundedRectangle(cornerRadius:18))}
}

struct RoundButton:View {
    var icon:String
    var label:String
    var palette:Palette
    var action:()->Void
    var body:some View{
        Button(action:action){Image(systemName:icon).font(.system(size:17,weight:.medium)).contentTransition(.symbolEffect(.replace))
                .frame(width:46,height:46).foregroundStyle(palette.ink).background(palette.inset.opacity(0.65),in:Circle())}
            .buttonStyle(ConsolePressStyle()).accessibilityLabel(label)
    }
}

struct PrimaryButton:View {
    var title:String
    var icon:String="arrow.right"
    var action:()->Void
    var body:some View{
        Button(action:action){HStack(spacing:10){Text(title);Image(systemName:icon).font(.system(size:13,weight:.semibold))}
                .font(.system(size:14,weight:.semibold)).padding(.horizontal,20).frame(minHeight:48)
                .foregroundStyle(Color(hex:0x17333C)).background(Color(hex:0xA5E4ED),in:RoundedRectangle(cornerRadius:14))}
            .buttonStyle(ConsolePressStyle())
    }
}
