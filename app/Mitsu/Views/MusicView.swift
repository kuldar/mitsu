import SwiftUI
import AVKit

struct MusicView:View {
    @EnvironmentObject var store:DashboardStore
    @Environment(\.openURL) var openURL
    @FocusState private var clientFocused:Bool
    var p:Palette{store.palette}
    var body:some View{
        GeometryReader{geometry in
            ScrollView{VStack(alignment:.leading,spacing:28){
                HStack{SectionHeading(title:store.spotify.connected ? "Now playing":"Your soundtrack",subtitle:"Spotify Connect",palette:p);Spacer();AudioRoutePicker().frame(width:44,height:44).accessibilityLabel("Choose audio output")}.padding(.top,10)
                if store.spotify.connected{nowPlaying(compact:geometry.size.width<760);devices}
                else{setup(compact:geometry.size.width<760)}
            }.padding(.horizontal,6).padding(.bottom,24)}.scrollDismissesKeyboard(.interactively)
        }.task{if store.spotify.connected{await store.spotify.refresh();await store.spotify.loadDevices()}}
    }
    func setup(compact:Bool)->some View{
        Group{
            if compact{VStack(alignment:.leading,spacing:32){musicIdentity(compact:true);ConsoleRule(palette:p);connection}}
            else{HStack(alignment:.top,spacing:52){musicIdentity(compact:false).frame(maxWidth:.infinity);connection.frame(width:400)}}
        }.padding(.top,16)
    }
    func musicIdentity(compact:Bool)->some View{
        VStack(alignment:.leading,spacing:26){
            AlbumArt(url:nil,size:compact ? 170:250,palette:p)
                .shadow(color:.black.opacity(p.dark ? 0.15:0.08),radius:25,x:0,y:14)
            VStack(alignment:.leading,spacing:12){
                Text("Make the drive yours.").font(.system(size:compact ? 29:34,weight:.light)).tracking(-0.8)
                Text("Play on your iPad, or control the phone already connected to your car.").font(.system(size:14)).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)
            }.frame(maxWidth:380,alignment:.leading)
        }
    }
    var connection:some View{
        VStack(alignment:.leading,spacing:20){
            Eyebrow(text:"Account connection").foregroundStyle(p.muted)
            Text("Connect your Spotify account").font(.system(size:23,weight:.medium)).tracking(-0.5)
            Text("Enter your Spotify developer app ID, then sign in to enable playback controls.").font(.system(size:13)).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)
            VStack(alignment:.leading,spacing:8){
                Text("CLIENT ID").font(.system(size:10,weight:.semibold)).tracking(1.2).foregroundStyle(p.muted)
                TextField("Spotify Client ID",text:Binding(get:{store.spotify.clientID},set:{store.spotify.clientID=$0})).textInputAutocapitalization(.never).autocorrectionDisabled().font(.system(size:14,design:.monospaced)).padding(15).background(p.inset.opacity(0.65),in:RoundedRectangle(cornerRadius:12)).focused($clientFocused).submitLabel(.done).onSubmit{clientFocused=false}
            }
            PrimaryButton(title:"Connect Spotify",icon:"arrow.up.right"){clientFocused=false;store.spotify.connect()}.disabled(!store.interactionAllowed)
            if !store.interactionAllowed{Label("Confirm you're parked in Settings to connect.",systemImage:"parkingsign.circle").font(.system(size:12)).foregroundStyle(p.muted)}
            ConsoleRule(palette:p)
            DisclosureGroup{
                VStack(alignment:.leading,spacing:12){
                    Text("Add this redirect URI to your Spotify developer app:").font(.system(size:12)).foregroundStyle(p.muted)
                    HStack{Text("com.example.mitsu://spotify-callback").font(.system(size:10,design:.monospaced)).textSelection(.enabled);Spacer();Button{UIPasteboard.general.string="com.example.mitsu://spotify-callback"}label:{Image(systemName:"doc.on.doc").frame(width:44,height:44)}.buttonStyle(ConsolePressStyle()).accessibilityLabel("Copy Spotify callback")}
                    Link("Open Spotify developer setup",destination:URL(string:"https://developer.spotify.com/dashboard")!).font(.system(size:12,weight:.medium)).frame(minHeight:44)
                    Text("Playback depends on Spotify account and developer access. Audio plays through Spotify on your selected device.").font(.system(size:11)).foregroundStyle(p.muted)
                }.padding(.top,12)
            }label:{Text("First-time setup").font(.system(size:13,weight:.medium)).frame(minHeight:44)}
            Text(store.spotify.status).font(.system(size:12)).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)
        }
    }
    func nowPlaying(compact:Bool)->some View{
        Group{
            if compact{VStack(alignment:.leading,spacing:28){AlbumArt(url:artURL,size:230,palette:p);playback}}
            else{HStack(alignment:.center,spacing:48){AlbumArt(url:artURL,size:300,palette:p).shadow(color:.black.opacity(0.12),radius:25,x:0,y:14);playback}}
        }.padding(.vertical,18)
    }
    var artURL:String?{store.spotify.playback?.item?.album?.images.first?.url}
    var playback:some View{
        VStack(alignment:.leading,spacing:19){
            Text(store.spotify.playback?.item?.name ?? "Ready to play").font(.system(size:34,weight:.light)).tracking(-0.8).lineLimit(3)
            Text(store.spotify.playback?.item?.artists?.map(\.name).joined(separator:", ") ?? "Start a track in Spotify on your playback device.").font(.system(size:15)).foregroundStyle(p.muted)
            if let duration=store.spotify.playback?.item?.duration_ms,duration>0{
                VStack(spacing:9){
                    ProgressView(value:min(1,Double(store.spotify.playback?.progress_ms ?? 0)/Double(duration))).tint(p.accentInk)
                    HStack{Text(time(store.spotify.playback?.progress_ms ?? 0));Spacer();Text(time(duration))}.font(.system(size:11)).monospacedDigit().foregroundStyle(p.muted)
                }.padding(.vertical,9)
            }
            HStack(spacing:20){
                playbackButton("backward.end.fill",label:"Previous Spotify track",command:"previous",large:false)
                playbackButton(store.spotify.playback?.is_playing == true ? "pause.fill":"play.fill",label:"Play or pause Spotify",command:store.spotify.playback?.is_playing == true ? "pause":"play",large:true)
                playbackButton("forward.end.fill",label:"Next Spotify track",command:"next",large:false)
                Spacer()
                Button{openURL(URL(string:"https://open.spotify.com")!)}label:{Image(systemName:"arrow.up.right").frame(width:44,height:44)}.buttonStyle(ConsolePressStyle()).accessibilityLabel("Open Spotify")
            }
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
    func playbackButton(_ icon:String,label:String,command:String,large:Bool)->some View{
        Button{store.spotify.control(command)}label:{Image(systemName:icon).font(.system(size:large ? 24:20,weight:.medium)).frame(width:large ? 72:48,height:large ? 72:48).foregroundStyle(large ? Color(hex:0x17333C):p.ink).background(large ? p.accent:Color.clear,in:Circle())}.buttonStyle(ConsolePressStyle()).accessibilityLabel(label).disabled(store.spotify.busy || store.spotify.playback == nil)
    }
    var devices:some View{
        VStack(alignment:.leading,spacing:15){
            ConsoleRule(palette:p)
            HStack{Eyebrow(text:"Playback device").foregroundStyle(p.muted);Spacer();Button("Refresh"){Task{await store.spotify.loadDevices()}}.font(.system(size:12,weight:.medium)).frame(minHeight:44)}
            ForEach(Array(store.spotify.devices.enumerated()),id:\.offset){_,device in
                Button{if let id=device.id{store.spotify.transfer(to:id)}}label:{HStack(spacing:14){Image(systemName:device.type == "Smartphone" ? "iphone":"hifispeaker").font(.system(size:19,weight:.light));Text(device.name);Spacer();if device.is_active{Label("Playing here",systemImage:"checkmark.circle.fill").font(.system(size:11)).foregroundStyle(p.accentInk)}}.font(.system(size:14)).frame(minHeight:52)}.buttonStyle(ConsolePressStyle()).disabled(device.id == nil || store.spotify.busy)
            }
            Text(store.spotify.status).font(.system(size:12)).foregroundStyle(p.muted)
        }
    }
    func time(_ milliseconds:Int)->String{let seconds=max(0,milliseconds/1000);return "\(seconds/60):\(String(format:"%02d",seconds%60))"}
}

struct AudioRoutePicker:UIViewRepresentable {
    func makeUIView(context:Context)->AVRoutePickerView{let v=AVRoutePickerView();v.tintColor = .secondaryLabel;return v}
    func updateUIView(_ view:AVRoutePickerView,context:Context){}
}
