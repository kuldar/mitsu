import SwiftUI

struct TripsView:View {
    @EnvironmentObject var store:DashboardStore
    @State private var clear=false
    var p:Palette{store.palette}
    var body:some View{
        ScrollView{VStack(alignment:.leading,spacing:28){
            HStack(alignment:.top){
                SectionHeading(title:store.trips.active ? "Journey in progress":"Your journeys",subtitle:"Recorded on this iPad, from measured vehicle speed.",palette:p)
                Spacer()
                if !store.trips.records.isEmpty{ShareLink(item:store.trips.exportText){Label("Export",systemImage:"square.and.arrow.up").font(.system(size:12,weight:.medium)).frame(minHeight:44)}}
            }.padding(.top,10)
            HStack(alignment:.center,spacing:28){
                VStack(alignment:.leading,spacing:14){
                    Eyebrow(text:store.trips.active ? "Recording locally":"Trip recorder").foregroundStyle(store.trips.active ? p.positive:p.muted)
                    HStack(alignment:.firstTextBaseline,spacing:8){Text(store.trips.active ? number(store.trips.accumulator.distanceKM):"—").font(.system(size:76,weight:.ultraLight)).tracking(-3).monospacedDigit();Text(store.imperial ? "mi":"km").font(.system(size:17)).foregroundStyle(p.muted)}
                    Text(store.trips.active ? "\(Int(store.now.timeIntervalSince(store.trips.started ?? store.now))/60) min elapsed · \(Int(store.trips.accumulator.coveredSeconds)) sec measured":"Connect the car to start a journey.").font(.system(size:12)).foregroundStyle(p.muted)
                }
                Spacer(minLength:12)
                PrimaryButton(title:store.trips.active ? "Finish journey":"Start journey",icon:store.trips.active ? "stop.fill":"arrow.right"){if store.trips.active{store.trips.end()}else{store.trips.begin()}}.disabled(!store.trips.active && (!store.diagnostics.live || store.preview))
            }.padding(.vertical,18)
            if let error=store.trips.errorMessage{Label(error,systemImage:"exclamationmark.circle").font(.system(size:12)).foregroundStyle(.orange)}
            ConsoleRule(palette:p)
            HStack{Eyebrow(text:"History").foregroundStyle(p.muted);Spacer();if !store.trips.records.isEmpty{Button("Delete history"){clear=true}.font(.system(size:12)).foregroundStyle(p.muted).frame(minHeight:44)}}
            if store.trips.records.isEmpty{
                ZStack{
                    JourneyTrace().stroke(p.line,style:StrokeStyle(lineWidth:1.5,lineCap:.round,dash:[5,8])).frame(maxWidth:640).frame(height:160).padding(.horizontal,30).accessibilityHidden(true)
                    VStack(spacing:12){Image(systemName:"point.bottomleft.forward.to.point.topright.scurvepath").font(.system(size:30,weight:.ultraLight)).foregroundStyle(p.accentInk);Text("No journeys yet").font(.system(size:21,weight:.light));Text(store.preview ? "Preview never records journeys.":"Your next recorded drive will appear here.").font(.system(size:12)).foregroundStyle(p.muted)}.padding(24).background(p.canvas.opacity(0.95))
                }.frame(maxWidth:.infinity).padding(.vertical,12)
            }else{
                LazyVStack(spacing:0){ForEach(store.trips.records){trip in
                    HStack(spacing:22){
                        Image(systemName:"arrow.up.right").font(.system(size:17,weight:.light)).foregroundStyle(p.muted).frame(width:30)
                        VStack(alignment:.leading,spacing:7){Text(trip.started,format:.dateTime.day().month(.wide).hour().minute()).font(.system(size:15,weight:.medium));Text("\(Int(trip.duration/60)) min · \(Int(trip.coverage*100))% measured coverage").font(.system(size:11)).foregroundStyle(p.muted)}
                        Spacer()
                        HStack(alignment:.firstTextBaseline,spacing:5){Text(number(trip.distanceKM)).font(.system(size:29,weight:.light)).monospacedDigit();Text(store.imperial ? "mi":"km").font(.system(size:11)).foregroundStyle(p.muted)}
                        Button{store.trips.delete(trip.id)}label:{Image(systemName:"trash").frame(width:44,height:44)}.buttonStyle(ConsolePressStyle()).foregroundStyle(p.muted).accessibilityLabel("Delete journey")
                    }.padding(.vertical,18)
                    ConsoleRule(palette:p)
                }}
            }
            Text("Measured distance is not the odometer. Gaps in speed data are excluded.").font(.system(size:11)).foregroundStyle(p.muted).padding(.bottom,20)
        }.padding(.horizontal,6)}.confirmationDialog("Delete all saved journeys?",isPresented:$clear,titleVisibility:.visible){Button("Delete history",role:.destructive){store.trips.deleteAll()}}
    }
    func number(_ km:Double)->String{(store.imperial ? km*0.621371:km).formatted(.number.precision(.fractionLength(1)))}
}

private struct JourneyTrace:Shape {
    func path(in r:CGRect)->Path{
        var p=Path();p.move(to:CGPoint(x:0,y:r.height*0.85));p.addCurve(to:CGPoint(x:r.width,y:r.height*0.15),control1:CGPoint(x:r.width*0.2,y:-r.height*0.3),control2:CGPoint(x:r.width*0.8,y:r.height*1.3));return p
    }
}
