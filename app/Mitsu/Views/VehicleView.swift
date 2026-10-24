import SwiftUI

struct SignalAvailability:Decodable,Identifiable {
    let id:String;let status:String;let system:String;let detail:String
    var title:String{id.replacingOccurrences(of:"_",with:" ").capitalized}
    static let all:[SignalAvailability]={guard let url=Bundle.main.url(forResource:"Signals",withExtension:"json"),let d=try? Data(contentsOf:url) else{return []};return (try? JSONDecoder().decode([SignalAvailability].self,from:d)) ?? []}()
}

struct VehicleView:View {
    @EnvironmentObject var store:DashboardStore
    @State private var availability=false
    var p:Palette{store.palette}
    var body:some View{
        ScrollView{
            VStack(alignment:.leading,spacing:28){
                HStack(alignment:.top){
                    SectionHeading(title:"Engine & diagnostics",subtitle:store.preview ? "Simulated data · connect your car for live readings":"Measured values from your diagnostic connection",palette:p)
                    Spacer(minLength:20)
                    Button{availability.toggle()}label:{HStack(spacing:8){Text(availability ? "Live readings":"What's available");Image(systemName:availability ? "waveform.path.ecg":"list.bullet")}.font(.system(size:12,weight:.medium)).padding(.horizontal,14).frame(minHeight:44).background(p.inset.opacity(0.7),in:Capsule())}.buttonStyle(ConsolePressStyle())
                }.padding(.top,10)
                if availability{capabilities}else{
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:260),spacing:30)],alignment:.leading,spacing:24){
                        ForEach(Signal.allCases.filter{$0 != .steering},id:\.self){signal in reading(signal)}
                    }
                    ConsoleRule(palette:p)
                    ViewThatFits(in:.horizontal){
                        HStack(alignment:.top,spacing:36){steering.frame(minWidth:300,maxWidth:.infinity);diagnostics.frame(minWidth:300,maxWidth:.infinity)}
                        VStack(alignment:.leading,spacing:28){steering;ConsoleRule(palette:p);diagnostics}
                    }
                    VehicleBodyView()
                    HStack(alignment:.top,spacing:12){Image(systemName:"info.circle").font(.system(size:15));Text("Window positions, tyre pressures, fuel level and climate controls remain unverified. No vehicle settings or actuator commands are enabled.").font(.system(size:12)).fixedSize(horizontal:false,vertical:true)}.foregroundStyle(p.muted).padding(.vertical,8)
                }
            }.padding(.horizontal,6).padding(.bottom,22)
        }
    }
    func reading(_ signal:Signal)->some View{
        VStack(alignment:.leading,spacing:12){
            HStack{Text(signal.title).font(.system(size:12,weight:.medium)).foregroundStyle(p.muted);Spacer();Image(systemName:icon(signal)).font(.system(size:14,weight:.light)).foregroundStyle(p.muted)}
            HStack(alignment:.firstTextBaseline,spacing:6){Text(store.text(signal)).font(.system(size:42,weight:.light)).tracking(-1.7).monospacedDigit();Text(store.unit(signal)).font(.system(size:12)).foregroundStyle(p.muted)}
            SignalTrend(values:store.history[signal] ?? []).stroke(p.accentInk,style:StrokeStyle(lineWidth:1.6,lineCap:.round,lineJoin:.round)).frame(height:25).accessibilityLabel("Recent \(signal.title.lowercased()) trend")
            Text(sampleDetail(signal)).font(.system(size:10)).foregroundStyle(p.muted).lineLimit(2).frame(minHeight:24,alignment:.top)
            ConsoleRule(palette:p)
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
    var steering:some View{
        VStack(alignment:.leading,spacing:18){
            Eyebrow(text:"Steering wheel").foregroundStyle(p.muted)
            HStack(spacing:20){
                Image(systemName:"steeringwheel").font(.system(size:64,weight:.ultraLight)).rotationEffect(.degrees(-(store.value(.steering) ?? 0))).frame(width:82,height:82).foregroundStyle(p.muted)
                VStack(alignment:.leading,spacing:6){Text(store.text(.steering)+"°").font(.system(size:36,weight:.light)).monospacedDigit();Text("Wheel angle · parked snapshot").font(.system(size:11)).foregroundStyle(p.muted)}
            }
            Button{store.diagnostics.enqueue(.steering)}label:{Label("Read steering angle",systemImage:"arrow.clockwise").font(.system(size:13,weight:.medium)).frame(minHeight:44)}.buttonStyle(ConsolePressStyle()).disabled(!store.interactionAllowed || !store.diagnostics.live || store.preview || store.diagnostics.diagnosticCheckBusy)
            Text("This is wheel angle, not tyre angle. Its scale has not been independently calibrated.").font(.system(size:11)).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)
        }
    }
    var diagnostics:some View{
        VStack(alignment:.leading,spacing:18){
            Eyebrow(text:"Emissions diagnostics").foregroundStyle(p.muted)
            HStack(alignment:.top,spacing:14){
                Image(systemName:"engine.combustion").font(.system(size:32,weight:.light)).foregroundStyle(p.muted).frame(height:66)
                VStack(alignment:.leading,spacing:8){
                    Text(store.diagnostics.codesRead ? store.diagnostics.codes.isEmpty ? "No codes returned":store.diagnostics.codes.joined(separator:", "):"Fault code scan").font(.system(size:24,weight:.light)).fixedSize(horizontal:false,vertical:true)
                    Text("Stored and pending emissions codes").font(.system(size:11)).foregroundStyle(p.muted)
                }.padding(.top,8)
            }
            Button{store.diagnostics.enqueue(.codes)}label:{Label("Read fault codes",systemImage:"magnifyingglass").font(.system(size:13,weight:.medium)).frame(minHeight:44)}.buttonStyle(ConsolePressStyle()).disabled(!store.interactionAllowed || !store.diagnostics.live || store.preview || store.diagnostics.diagnosticCheckBusy)
            Text("Read-only. This does not check every vehicle system, clear codes or reset the car.").font(.system(size:11)).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)
        }
    }
    var capabilities:some View{
        LazyVStack(alignment:.leading,spacing:0){ForEach(SignalAvailability.all){item in
            VStack(alignment:.leading,spacing:9){
                HStack{Text(item.title).font(.system(size:15,weight:.medium));Spacer(minLength:16);StatusPill(text:status(item.status),color:item.status == "confirmed_and_validated" ? p.positive:p.muted)}
                Text(item.detail).font(.system(size:12)).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)
            }.padding(.vertical,18)
            ConsoleRule(palette:p)
        }}
    }
    func icon(_ signal:Signal)->String{
        switch signal{case .speed:return "speedometer";case .rpm:return "gauge.with.dots.needle.50percent";case .coolant,.intake:return "thermometer.medium";case .voltage,.supply:return "bolt";case .load:return "engine.combustion";case .throttle:return "pedal.accelerator";case .airflow:return "wind";case .steering:return "steeringwheel"}
    }
    func status(_ s:String)->String{switch s{case "confirmed_and_validated":return "Observed";case "observed_but_not_decoded":return "Needs validation";case "documented_but_not_tested":return "Untested";default:return "Unavailable"}}
    func sampleDetail(_ signal:Signal)->String{
        guard let sample=store.snapshot.samples[signal]else{return "Waiting for a supported reading"}
        if store.preview{return "Simulated · preview only"}
        return sample.isFresh(at:store.uptime) && store.diagnostics.live ? "From \(sample.ecu) · \(Int(max(0,store.uptime-sample.uptime)))s ago":"Last received \(Int(max(0,store.uptime-sample.uptime)))s ago · stale"
    }
}

struct SignalTrend:Shape {
    var values:[Double]
    func path(in rect:CGRect)->Path{
        var path=Path();guard values.count>1,let low=values.min(),let high=values.max() else{return path}
        let range=max(high-low,abs(high)*0.04,1)
        for (i,v) in values.enumerated(){let point=CGPoint(x:rect.width*Double(i)/Double(values.count-1),y:rect.height*(0.8-0.6*(v-low)/range));if i==0{path.move(to:point)}else{path.addLine(to:point)}}
        return path
    }
}
