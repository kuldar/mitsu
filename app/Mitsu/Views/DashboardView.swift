import SwiftUI

struct DashboardView:View {
    @EnvironmentObject var store:DashboardStore
    @Environment(\.scenePhase) var phase
    @Environment(\.accessibilityReduceMotion) var reducedMotion
    var p:Palette{store.palette}
    var body:some View{
        GeometryReader{geometry in
            let compact=geometry.size.width<850
            HStack(spacing:0){
                rail(compact:compact)
                VStack(spacing:0){
                    header(compact:compact).padding(.bottom,14)
                    Group{
                        switch store.tab{
                        case .drive:DriveView()
                        case .vehicle:VehicleView()
                        case .trips:TripsView()
                        case .map:DashboardMapView()
                        case .music:MusicView()
                        case .settings:SettingsView()
                        }
                    }.frame(maxWidth:.infinity,maxHeight:.infinity)
                    MiniPlayer(palette:p).padding(.top,12)
                }.padding(.horizontal,compact ? 24:30).padding(.top,18).padding(.bottom,12)
            }.background(p.canvas).foregroundStyle(p.ink)
                .animation(reducedMotion ? nil:.easeInOut(duration:0.2),value:store.isDark)
                .tint(p.accentInk)
                .buttonStyle(ConsolePressStyle())
        }
        .onChange(of:phase){_,value in store.setActive(value == .active)}
        .onChange(of:store.active && store.diagnostics.live,initial:true){_,connected in UIApplication.shared.isIdleTimerDisabled=connected}
        .onDisappear{UIApplication.shared.isIdleTimerDisabled=false}
        .statusBarHidden()
    }
    func rail(compact:Bool)->some View{
        VStack(spacing:8){
            MitsuMark().fill(p.ink).frame(width:27,height:38).padding(.vertical,20).accessibilityLabel("Mitsu")
            ForEach(DashboardTab.allCases.filter{$0 != .settings},id:\.self){tab in navItem(tab)}
            Spacer(minLength:20)
            navItem(.settings).padding(.bottom,16)
        }.frame(width:compact ? 72:78).background(p.surface.opacity(p.dark ? 0.36:0.42))
            .overlay(alignment:.trailing){Rectangle().fill(p.line.opacity(0.6)).frame(width:1)}
    }
    func navItem(_ tab:DashboardTab)->some View{
        let selected=store.tab==tab
        return Button{store.tab=tab}label:{
            VStack(spacing:6){
                Image(systemName:tab.icon).font(.system(size:21,weight:selected ? .semibold:.regular)).frame(height:25)
                Text(tab.rawValue).font(.system(size:10,weight:selected ? .semibold:.medium))
            }.frame(maxWidth:.infinity).frame(height:65).foregroundStyle(selected ? p.ink:p.muted)
                .background{if selected{RoundedRectangle(cornerRadius:16).fill(p.inset.opacity(0.65)).padding(.horizontal,10)}}
                .overlay(alignment:.leading){if selected{Capsule().fill(p.accentInk).frame(width:3,height:25)}}
                .contentShape(Rectangle())
                .animation(reducedMotion ? nil:.easeOut(duration:0.16),value:selected)
        }.buttonStyle(ConsolePressStyle()).accessibilityLabel(tab.rawValue).accessibilityAddTraits(selected ? .isSelected:[])
    }
    func header(compact:Bool)->some View{
        HStack(spacing:14){
            HStack(alignment:.firstTextBaseline,spacing:12){
                Text(store.tab == .drive ? "OUTLANDER":store.tab.rawValue).font(.system(size:store.tab == .drive ? 16:23,weight:.semibold)).tracking(store.tab == .drive ? 3:-0.5).accessibilityIdentifier("page-title")
                if !compact{Text(store.tab == .drive ? "MITSUBISHI / 2014–15":"OUTLANDER").font(.system(size:9,weight:.medium)).tracking(1.4).foregroundStyle(p.muted)}
            }
            Spacer(minLength:10)
            if store.preview{
                Button{store.setPreview(false)}label:{StatusPill(text:"Preview",color:p.accentInk).frame(minHeight:44).contentShape(Rectangle())}.buttonStyle(ConsolePressStyle()).accessibilityLabel("Exit simulated preview")
            }else{
                Button{store.tab = .settings}label:{StatusPill(text:store.diagnostics.live ? "Connected":"Offline",color:store.diagnostics.live ? p.positive:p.muted).frame(minHeight:44).contentShape(Rectangle())}.buttonStyle(ConsolePressStyle()).accessibilityLabel("Car connection settings").accessibilityValue(store.connectionLabel)
            }
            if let w=store.weather.snapshot,store.weather.freshness(at:store.now) != .expired,!store.preview{
                Label("\(Int(w.temperature.rounded()))°",systemImage:w.kind.symbol).font(.system(size:14,weight:.medium)).foregroundStyle(p.muted)
                    .accessibilityLabel("Weather for \(store.weather.area?.name ?? "selected area"), \(Int(w.temperature.rounded())) degrees\(store.weather.freshness(at:store.now) == .cached ? ", cached":"")")
            }
            Text(store.now,style:.time).font(.system(size:17,weight:.medium)).monospacedDigit()
            Button{store.appearance=store.isDark ? "Light":"Dark"}label:{Image(systemName:store.isDark ? "sun.max":"moon").font(.system(size:18,weight:.regular)).frame(width:44,height:44).contentTransition(.symbolEffect(.replace))}
                .buttonStyle(ConsolePressStyle()).accessibilityLabel("Switch day and night appearance").accessibilityValue(store.isDark ? "Night":"Day")
        }.frame(height:48)
    }
}

struct MiniPlayer:View {
    @EnvironmentObject var store:DashboardStore
    var palette:Palette
    var body:some View{
        VStack(spacing:0){
            ConsoleRule(palette:palette)
            HStack(spacing:14){
                if store.tab == .music{
                    Image(systemName:"hifispeaker").font(.system(size:19,weight:.light)).frame(width:46,height:46).foregroundStyle(palette.muted)
                    VStack(alignment:.leading,spacing:4){Text("Audio output").font(.system(size:13,weight:.semibold));Text(store.spotify.playback?.device?.name ?? "Managed in Spotify").font(.system(size:11)).foregroundStyle(palette.muted)}.frame(maxWidth:.infinity,alignment:.leading)
                }else{
                Button{store.tab = .music}label:{AlbumArt(url:store.spotify.playback?.item?.album?.images.first?.url,size:42,palette:palette).frame(width:46,height:46).contentShape(Rectangle())}.buttonStyle(ConsolePressStyle()).accessibilityLabel("Open Spotify music")
                Button{store.tab = .music}label:{
                    VStack(alignment:.leading,spacing:4){
                        Text(store.spotify.playback?.item?.name ?? "Your soundtrack").font(.system(size:13,weight:.semibold)).lineLimit(1)
                        Text(store.spotify.playback?.item?.artists?.map(\.name).joined(separator:", ") ?? (store.spotify.connected ? store.spotify.status:"Connect Spotify")).font(.system(size:11)).foregroundStyle(palette.muted).lineLimit(1)
                    }.frame(maxWidth:.infinity,alignment:.leading).frame(minHeight:44)
                }.buttonStyle(ConsolePressStyle()).accessibilityLabel("Open music details")
                    .accessibilityValue((store.spotify.playback?.item?.name ?? "Your soundtrack")+", "+(store.spotify.playback?.item?.artists?.map(\.name).joined(separator:", ") ?? (store.spotify.connected ? store.spotify.status:"Connect Spotify")))
                if store.spotify.connected{playerControls(palette:palette)}
                else{Button{store.tab = .music}label:{Image(systemName:"arrow.up.right").font(.system(size:16,weight:.medium)).frame(width:44,height:44)}.buttonStyle(ConsolePressStyle()).accessibilityLabel("Connect Spotify music")}
                }
                Rectangle().fill(palette.line).frame(width:1,height:28).padding(.horizontal,8)
                Button{store.tab = .settings}label:{
                    HStack(spacing:9){Image(systemName:store.preview ? "play.rectangle":store.diagnostics.live ? "antenna.radiowaves.left.and.right":"cable.connector").font(.system(size:17))
                        VStack(alignment:.leading,spacing:4){Text(store.preview ? "Simulated readings":store.diagnostics.live ? "KW906 connected":"Connect your car").font(.system(size:11,weight:.medium));Text(store.preview ? "Preview mode":store.diagnostics.live ? "Live · read-only":"Ready when you are").font(.system(size:10)).foregroundStyle(palette.muted)}
                    }.frame(minHeight:48)
                }.buttonStyle(ConsolePressStyle()).accessibilityLabel("Open car connection settings").accessibilityValue(store.connectionLabel)
            }.padding(.top,12).padding(.bottom,2)
        }
    }
    @ViewBuilder func playerControls(palette:Palette)->some View{
        HStack(spacing:4){
            Button{store.spotify.control("previous")}label:{Image(systemName:"backward.end.fill").frame(width:44,height:44)}.accessibilityLabel("Previous Spotify track")
            Button{store.spotify.control(store.spotify.playback?.is_playing == true ? "pause":"play")}label:{Image(systemName:store.spotify.playback?.is_playing == true ? "pause.fill":"play.fill").frame(width:44,height:44).background(palette.inset,in:Circle())}.accessibilityLabel("Play or pause Spotify")
            Button{store.spotify.control("next")}label:{Image(systemName:"forward.end.fill").frame(width:44,height:44)}.accessibilityLabel("Next Spotify track")
        }.font(.system(size:15,weight:.medium)).buttonStyle(ConsolePressStyle()).disabled(store.spotify.busy || store.spotify.playback == nil)
    }
}

struct AlbumArt:View {
    var url:String?
    var size:CGFloat
    var palette:Palette
    var body:some View{
        Group{
            if let url,let u=URL(string:url){AsyncImage(url:u){image in image.resizable().scaledToFill()}placeholder:{fallback}}
            else{fallback}
        }.frame(width:size,height:size).clipShape(RoundedRectangle(cornerRadius:size*0.15))
    }
    var fallback:some View{
        ZStack{
            LinearGradient(colors:[Color(hex:0x344B59),Color(hex:0x101D29)],startPoint:.topLeading,endPoint:.bottomTrailing)
            Image(systemName:"waveform").font(.system(size:size*0.34,weight:.light)).foregroundStyle(Color(hex:0xB7DBE3))
        }
    }
}
