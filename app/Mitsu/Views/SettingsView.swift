import SwiftUI

struct SettingsView:View {
    @EnvironmentObject var store:DashboardStore
    @State private var confirmParked=false
    var p:Palette{store.palette}
    var body:some View{
        GeometryReader{geometry in
            ScrollView{VStack(alignment:.leading,spacing:30){
                SectionHeading(title:"Connection & preferences",subtitle:"Set up your Outlander and make the display yours.",palette:p).padding(.top,10)
                if geometry.size.width>760{
                    HStack(alignment:.top,spacing:50){
                        VStack(alignment:.leading,spacing:32){connection;weather}.frame(maxWidth:.infinity,alignment:.leading)
                        VStack(alignment:.leading,spacing:32){appearance;experience}.frame(maxWidth:.infinity,alignment:.leading)
                    }
                }else{VStack(alignment:.leading,spacing:32){connection;appearance;weather;experience}}
                Text("MITSU / OUTLANDER / iPad").font(.system(size:9,weight:.medium)).tracking(1.8).foregroundStyle(p.muted).padding(.vertical,12)
            }.padding(.horizontal,6).padding(.bottom,18)}
        }.alert("Are you safely parked?",isPresented:$confirmParked){Button("I'm parked"){store.parked=true};Button("Cancel",role:.cancel){}}message:{Text("Detailed setup and free 3D interaction are for use while parked. Zero speed alone does not establish Park.")}
    }
    func heading(_ title:String,icon:String)->some View{
        HStack(spacing:10){Image(systemName:icon).font(.system(size:17,weight:.light)).frame(width:22);Text(title).font(.system(size:16,weight:.medium));Spacer()}
    }
    var connection:some View{
        VStack(alignment:.leading,spacing:17){
            ConsoleRule(palette:p);heading("Car connection",icon:"antenna.radiowaves.left.and.right")
            HStack(alignment:.top){
                VStack(alignment:.leading,spacing:6){Text("KONNWEI KW906").font(.system(size:19,weight:.light));Text(store.bluetooth.status).font(.system(size:12)).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)}
                Spacer();StatusPill(text:store.diagnostics.live ? "Live":"Offline",color:store.diagnostics.live ? p.positive:p.muted)
            }
            Text("Plug in your adapter and close other OBD apps before connecting.").font(.system(size:12)).foregroundStyle(p.muted)
            if store.bluetooth.ready{PrimaryButton(title:"Disconnect",icon:"xmark"){store.bluetooth.disconnect()}}
            else{PrimaryButton(title:store.bluetooth.scanning ? "Stop searching":"Find adapter",icon:"antenna.radiowaves.left.and.right"){if store.bluetooth.scanning{store.bluetooth.stopScan()}else{store.startScan()}}.disabled(!store.interactionAllowed)}
            ForEach(store.bluetooth.devices){device in
                Button{store.bluetooth.connect(device.id)}label:{HStack{Text(device.name);Spacer();Text("\(device.rssi) dBm").foregroundStyle(p.muted);Image(systemName:"chevron.right")}.font(.system(size:13)).frame(minHeight:48)}.buttonStyle(ConsolePressStyle()).disabled(!store.interactionAllowed || store.preview || store.bluetooth.ready)
            }
            if store.diagnostics.live || store.diagnostics.status != "Waiting for adapter"{Text(store.diagnostics.status).font(.system(size:11)).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)}
            Toggle("I'm safely parked",isOn:Binding(get:{store.parked},set:{if $0{confirmParked=true}else{store.parked=false}})).font(.system(size:13)).tint(p.accentInk).frame(minHeight:44)
            Text("Read-only connection. Vehicle controls are not enabled.").font(.system(size:11)).foregroundStyle(p.muted)
        }
    }
    var appearance:some View{
        VStack(alignment:.leading,spacing:18){
            ConsoleRule(palette:p);heading("Display",icon:"circle.lefthalf.filled")
            Picker("Appearance",selection:$store.appearance){ForEach(["Auto","Light","Dark"],id:\.self){Text($0)}}.pickerStyle(.segmented)
            Text("Auto follows sunrise and sunset in your weather area, with a local-clock fallback.").font(.system(size:12)).foregroundStyle(p.muted)
            Toggle("Miles & Fahrenheit",isOn:$store.imperial).font(.system(size:13)).tint(p.accentInk).frame(minHeight:44)
        }
    }
    var weather:some View{
        VStack(alignment:.leading,spacing:17){
            ConsoleRule(palette:p);heading("Surroundings",icon:store.kind.symbol)
            HStack(alignment:.firstTextBaseline){Text(store.weather.area?.name ?? "Choose a weather area").font(.system(size:19,weight:.light));Spacer();if let w=store.weather.snapshot,store.weather.freshness(at:store.now) != .expired{Text("\(Int(w.temperature.rounded()))°C").font(.system(size:23,weight:.light))}}
            if store.weather.area != nil || store.weather.loading{Text(store.weather.status).font(.system(size:12)).foregroundStyle(p.muted)}
            HStack(spacing:8){ForEach([WeatherArea.tallinn,.tartu,.parnu],id:\.id){area in
                Button{store.weather.select(area)}label:{Text(area.name).font(.system(size:12,weight:.medium)).frame(maxWidth:.infinity).frame(minHeight:44).foregroundStyle(store.weather.area?.id==area.id ? p.accentInk:p.muted).background(store.weather.area?.id==area.id ? p.accentInk.opacity(0.1):p.inset.opacity(0.6),in:RoundedRectangle(cornerRadius:12))}.buttonStyle(ConsolePressStyle())
            }}
            if let w=store.weather.snapshot,store.weather.freshness(at:store.now) != .expired{
                Text("\(w.kind.label) · Wind \(Int(w.wind)) km/h · \(store.weather.freshness(at:store.now) == .cached ? "Cached":"Current")").font(.system(size:12)).foregroundStyle(p.muted)
                Text("Updated \(w.fetched.formatted(date:.omitted,time:.shortened))").font(.system(size:10)).foregroundStyle(p.muted)
            }
            HStack{Button("Refresh weather"){store.weather.refresh(force:true)}.disabled(store.weather.loading || store.weather.area == nil);Spacer();Link("Open-Meteo",destination:URL(string:"https://open-meteo.com")!)}.font(.system(size:12,weight:.medium)).frame(minHeight:44)
            Text("No GPS needed. Choose another area on the map. Surroundings illustrate regional weather, not sensors on your car.").font(.system(size:11)).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)
        }
    }
    var experience:some View{
        VStack(alignment:.leading,spacing:18){
            ConsoleRule(palette:p);heading("Experience",icon:"slider.horizontal.3")
            Toggle("Simulated preview",isOn:Binding(get:{store.preview},set:{store.setPreview($0)})).font(.system(size:13)).tint(p.accentInk).frame(minHeight:44)
            Text("Preview disconnects the adapter. Simulated readings never become saved journeys.").font(.system(size:12)).foregroundStyle(p.muted)
            if store.preview{Picker("Scene weather",selection:$store.previewWeather){ForEach([WeatherKind.clear,.cloud,.rain,.snow,.fog],id:\.self){Text($0.label).tag($0)}}.pickerStyle(.menu).font(.system(size:13)).frame(minHeight:44)}
            ConsoleRule(palette:p)
            HStack{Label("Spotify",systemImage:"music.note").font(.system(size:13,weight:.medium));Spacer();Button(store.spotify.connected ? "Disconnect":"Set up"){if store.spotify.connected{store.spotify.disconnect()}else{store.tab = .music}}.font(.system(size:12,weight:.medium)).frame(minHeight:44)}
            Text("Music plays on your Spotify device. Adjust the car stereo's volume on the stereo.").font(.system(size:11)).foregroundStyle(p.muted)
        }
    }
}
