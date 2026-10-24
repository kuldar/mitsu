import Combine
import SwiftUI

enum DashboardTab:String,CaseIterable {case drive="Drive",vehicle="Vehicle",trips="Trips",map="Map",music="Music",settings="Settings"
    var icon:String{switch self{case .drive:return "steeringwheel";case .vehicle:return "car.side";case .trips:return "point.bottomleft.forward.to.point.topright.scurvepath";case .map:return "map";case .music:return "music.note";case .settings:return "slider.horizontal.3"}}
}

@MainActor final class DashboardStore:ObservableObject {
    @Published var tab:DashboardTab = .drive
    @Published private(set) var preview=false
    @Published var appearance=UserDefaults.standard.string(forKey:"appearance") ?? "Auto" {didSet{UserDefaults.standard.set(appearance,forKey:"appearance")}}
    @Published var imperial=UserDefaults.standard.bool(forKey:"imperial") {didSet{UserDefaults.standard.set(imperial,forKey:"imperial")}}
    @Published var parked=false
    @Published var previewWeather:WeatherKind = .cloud
    @Published var snapshot=VehicleSnapshot()
    @Published var body=BodySnapshot()
    @Published var previewBody:Set<BodySignal>=[]
    @Published private(set) var history:[Signal:[Double]]=[:]
    @Published var now=Date()
    // Live samples arrive between timer ticks. A cached clock would briefly
    // classify each new sample as being in the future and blank its readout.
    var uptime:TimeInterval{ProcessInfo.processInfo.systemUptime}
    @Published var active=true
    let bluetooth=BluetoothClient()
    let diagnostics:DiagnosticSession
    let weather=WeatherService()
    let spotify=SpotifyService()
    let trips=TripStore()
    let location=LocationService()
    private var subscriptions=Set<AnyCancellable>()
    private var counter=0
    init() {
        diagnostics=DiagnosticSession(bluetooth:bluetooth)
        diagnostics.onSample = {[weak self] sample in guard let self,!self.preview else{return};self.snapshot.samples[sample.signal]=sample;self.appendHistory(sample);self.trips.accept(sample)}
        diagnostics.onStop = {[weak self] in self?.trips.end();self?.body=BodySnapshot()}
        diagnostics.parkedForBodyCheck = {[weak self] in
            guard let self else{return false}
            return !self.preview && self.parked && self.value(.speed)==0
        }
        diagnostics.bodyCheckStillParked = {[weak self] in
            guard let self else{return false}
            return !self.preview && self.active && self.parked && (self.value(.speed) ?? 0)<=0
        }
        for publisher in [bluetooth.objectWillChange,diagnostics.objectWillChange,weather.objectWillChange,spotify.objectWillChange,trips.objectWillChange,location.objectWillChange] {
            publisher.sink{[weak self] _ in self?.objectWillChange.send()}.store(in:&subscriptions)
        }
        Timer.publish(every:0.5,on:.main,in:.common).autoconnect().sink{[weak self] date in self?.tick(date)}.store(in:&subscriptions)
        if ProcessInfo.processInfo.arguments.contains("--preview") {setPreview(true);parked=true}
        if ProcessInfo.processInfo.arguments.contains("--night") {appearance="Dark"}
        if ProcessInfo.processInfo.arguments.contains("--day") {appearance="Light"}
        if preview,let arg=ProcessInfo.processInfo.arguments.first(where:{$0.hasPrefix("--weather=")}),let weather=WeatherKind(rawValue:String(arg.dropFirst(10))){previewWeather=weather}
        if preview,let arg=ProcessInfo.processInfo.arguments.first(where:{$0.hasPrefix("--body=")}){
            previewBody=Set(arg.dropFirst(7).split(separator:",").compactMap{BodySignal(rawValue:String($0))})
        }
        if let arg=ProcessInfo.processInfo.arguments.first(where:{$0.hasPrefix("--tab=")}),let t=DashboardTab(rawValue:String(arg.dropFirst(6)).capitalized){tab=t}
    }
    var isDark:Bool {
        if appearance != "Auto"{return appearance == "Dark"}
        if weather.freshness(at:now) != .expired,let w=weather.snapshot,let rise=w.sunrise,let set=w.sunset {return now<rise || now>=set}
        let hour=Calendar.current.component(.hour,from:now);return hour<7 || hour>=19
    }
    var palette:Palette{Palette(dark:isDark)}
    var kind:WeatherKind{preview ? previewWeather : (weather.freshness(at:now) == .expired ? .neutral : weather.snapshot?.kind ?? .neutral)}
    var interactionAllowed:Bool{parked && (value(.speed) ?? 0)<=0 || preview}
    func value(_ signal:Signal)->Double?{snapshot.value(signal,at:uptime,connected:diagnostics.live,preview:preview)}
    var bodyValues:[BodySignal:Bool] {
        if preview{return Dictionary(uniqueKeysWithValues:BodySignal.allCases.map{($0,previewBody.contains($0))})}
        return BodySignal.allCases.reduce(into:[:]){result,signal in
            result[signal]=body.value(signal,at:uptime,connected:diagnostics.live,preview:false)
        }
    }
    func text(_ signal:Signal)->String {
        guard var v=value(signal) else{return "—"}
        if imperial {if signal == .speed{v *= 0.621371};if signal == .coolant || signal == .intake{v=v*9/5+32}}
        return v.formatted(.number.precision(.fractionLength(signal.decimals)))
    }
    func unit(_ signal:Signal)->String{if imperial{if signal == .speed{return "mph"};if signal == .coolant || signal == .intake{return "°F"}};return signal.unit}
    var connectionLabel:String{preview ? "Preview · simulated" : diagnostics.live ? "Connected · KW906" : "Not connected"}
    func setPreview(_ enabled:Bool){bluetooth.disconnect();bluetooth.sourceMode=enabled ? .preview:.live;preview=enabled;snapshot=VehicleSnapshot();body=BodySnapshot();previewBody=[];history=[:];trips.end();if enabled{updatePreview()}}
    func setActive(_ active:Bool){self.active=active;if !active{bluetooth.disconnect();trips.end()}else{weather.refresh();Task{await spotify.refresh()}}}
    func startScan(){if preview{setPreview(false)};bluetooth.scan()}
    private func tick(_ date:Date){
        now=date;guard active else{return};counter += 1
        if preview{updatePreview()}
        if !preview,let speed=value(.speed),speed>0{parked=false}
        if counter%20==0{Task{await spotify.refresh()}}
        if counter%120==0{weather.refresh()}
    }
    private func updatePreview(){
        let phase=uptime/6
        let values:[Signal:Double]=[.speed:64,.rpm:1840+sin(phase)*70,.coolant:84,.intake:19,.voltage:14.3,.supply:14.1,.load:32+sin(phase)*3,.throttle:18,.airflow:12.8,.steering:sin(phase)*12]
        for (s,v) in values{let sample=Sample(signal:s,value:v,ecu:"Preview",uptime:uptime,source:.preview);snapshot.samples[s]=sample;appendHistory(sample)}
    }
    private func appendHistory(_ sample:Sample){history[sample.signal,default:[]].append(sample.value);if history[sample.signal,default:[]].count>90{history[sample.signal]?.removeFirst()}}
}
