import SwiftUI

struct DriveView:View {
    @EnvironmentObject var store:DashboardStore
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var reset=0
    var p:Palette{store.palette}
    var body:some View{
        GeometryReader{geometry in
            // Preserve one hierarchy through intermediate rotation sizes. Swapping
            // ScrollView/VStack here destroys the renderer and resets its camera.
            VStack(spacing:0){stage(compact:geometry.size.width<760);instruments}
                .frame(width:geometry.size.width,height:geometry.size.height)
        }
    }
    func stage(compact:Bool)->some View{
        GeometryReader{geometry in
            let aspect=max(0.55,geometry.size.width/max(1,geometry.size.height))
            // Preserve a comfortable horizontal field of view in tall windows.
            let fieldOfView:Float=aspect<1 ? Float(2*atan(tan(Double.pi/10)/Double(aspect))*180/Double.pi):36
            ZStack(alignment:.topLeading){
                VehicleScene(dark:store.isDark,weather:store.kind,interactive:store.interactionAllowed,reducedMotion:reduceMotion,active:store.active,speed:store.value(.speed),reset:reset,horizontalFraming:compact ? 0:0.55,verticalFieldOfView:fieldOfView,bodyValues:store.bodyValues,bodyPreview:store.preview)
                    .overlay(alignment:.leading){if !compact{LinearGradient(colors:[p.canvas,p.canvas.opacity(0)],startPoint:.leading,endPoint:.trailing).frame(width:230).allowsHitTesting(false)}}
                    .overlay(alignment:.top){LinearGradient(colors:[p.canvas,p.canvas.opacity(0)],startPoint:.top,endPoint:.bottom).frame(height:120).allowsHitTesting(false)}
                    .overlay(alignment:.bottom){LinearGradient(colors:[p.canvas.opacity(0),p.canvas],startPoint:.top,endPoint:.bottom).frame(height:70).allowsHitTesting(false)}
                    .accessibilityLabel("Interactive black pre-facelift Outlander 3D illustration")
                VStack(alignment:.leading,spacing:0){
                    VStack(alignment:.leading,spacing:0){
                        Text(store.text(.speed)).font(.system(size:compact ? 116:142,weight:.light)).tracking(-9).monospacedDigit().contentTransition(.numericText())
                        HStack(spacing:12){Text(store.unit(.speed)).font(.system(size:16,weight:.medium));Rectangle().fill(p.line).frame(width:1,height:13);Text(store.preview ? "SIMULATED SPEED":store.diagnostics.live ? "VEHICLE SPEED":"WAITING FOR YOUR CAR").font(.system(size:9,weight:.semibold)).tracking(1.1)}.foregroundStyle(p.muted)
                    }
                    if !store.preview && !store.diagnostics.live{
                        Button{store.tab = .settings}label:{HStack(spacing:7){Text("Connect car");Image(systemName:"arrow.up.right")}.font(.system(size:12,weight:.semibold)).foregroundStyle(p.accentInk).frame(minHeight:44)}.buttonStyle(ConsolePressStyle()).padding(.top,8)
                    }
                    Spacer()
                    VStack(alignment:.leading,spacing:12){
                        HStack(alignment:.firstTextBaseline,spacing:6){Text(store.text(.rpm)).font(.system(size:31,weight:.light)).monospacedDigit();Text("rpm").font(.system(size:12)).foregroundStyle(p.muted)}
                        HStack(spacing:3){ForEach(0..<28,id:\.self){i in Capsule().fill(Double(i)<(store.value(.rpm) ?? 0)/8000*28 ? p.accentInk:p.line).frame(width:4,height:14)}}.accessibilityHidden(true)
                        Eyebrow(text:"Engine speed").foregroundStyle(p.muted)
                    }.padding(.bottom,44)
                }.padding(.leading,6).padding(.top,8)
                VStack(alignment:.trailing,spacing:7){
                    HStack(spacing:8){Image(systemName:store.kind.symbol).font(.system(size:23,weight:.light));Text(store.kind.label).font(.system(size:13,weight:.medium))}
                    Text(store.preview ? "Preview scene":store.weather.area?.name ?? "Weather not selected").font(.system(size:10)).foregroundStyle(p.muted)
                    if store.trips.active{
                        HStack(spacing:5){Circle().fill(p.positive).frame(width:5,height:5);Text("RECORDING").tracking(1)}.font(.system(size:9,weight:.semibold)).foregroundStyle(p.positive).padding(.top,24)
                        Text(distance(store.trips.accumulator.distanceKM)+" "+(store.imperial ? "mi":"km")).font(.system(size:24,weight:.light)).monospacedDigit()
                        Text("\(Int(store.now.timeIntervalSince(store.trips.started ?? store.now))/60) min").font(.system(size:11)).foregroundStyle(p.muted)
                    }
                }.frame(maxWidth:.infinity,alignment:.trailing).padding(.trailing,6).padding(.top,30)
                HStack(alignment:.bottom){
                    HStack(spacing:6){Image(systemName:"hand.draw");Text(store.interactionAllowed ? "Drag to rotate · Pinch to explore":"Explore when parked")}.font(.system(size:10)).foregroundStyle(p.muted)
                    Spacer()
                    Text(store.preview ? "Illustrative surroundings":"Body states unverified · Illustrative surroundings").font(.system(size:9)).foregroundStyle(p.muted.opacity(0.8))
                    if store.interactionAllowed{RoundButton(icon:"arrow.counterclockwise",label:"Reset car view",palette:p){reset += 1}.padding(.leading,8)}
                }.frame(maxHeight:.infinity,alignment:.bottom).padding(.bottom,12).padding(.horizontal,6)
            }.clipped()
        }
    }
    var instruments:some View{
        Button{store.tab = .vehicle}label:{
            VStack(alignment:.leading,spacing:18){
                ConsoleRule(palette:p)
                HStack(spacing:14){
                    ForEach([Signal.coolant,.voltage,.load,.intake],id:\.self){signal in
                        VStack(alignment:.leading,spacing:9){
                            Text(signal.title).font(.system(size:11,weight:.medium)).foregroundStyle(p.muted)
                            HStack(alignment:.firstTextBaseline,spacing:4){Text(store.text(signal)).font(.system(size:29,weight:.light)).monospacedDigit();Text(store.unit(signal)).font(.system(size:11)).foregroundStyle(p.muted)}
                        }.frame(maxWidth:.infinity,alignment:.leading)
                    }
                    Image(systemName:"arrow.up.right").font(.system(size:16,weight:.light)).foregroundStyle(p.muted).frame(width:40,height:44)
                }
                HStack(spacing:6){Circle().fill(store.diagnostics.live ? p.positive:p.muted).frame(width:4,height:4);Text(store.preview ? "Preview data":store.diagnostics.live ? "Live engine telemetry":"Readings appear after connection").font(.system(size:10));Spacer();Text("Engine details").font(.system(size:10,weight:.medium))}.foregroundStyle(p.muted)
            }.padding(.horizontal,6).padding(.bottom,8).contentShape(Rectangle())
        }.buttonStyle(ConsolePressStyle()).accessibilityLabel("Open engine details")
            .accessibilityValue([Signal.coolant,.voltage,.load,.intake].map{$0.title+", "+store.text($0)+" "+store.unit($0)}.joined(separator:"; "))
    }
    func distance(_ km:Double)->String{(store.imperial ? km*0.621371:km).formatted(.number.precision(.fractionLength(1)))}
}
