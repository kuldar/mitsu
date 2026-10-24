import Foundation

struct WeatherArea: Codable, Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
    var id: String { String(format:"%.4f,%.4f",latitude,longitude) }
    static let tallinn=WeatherArea(name:"Tallinn",latitude:59.437,longitude:24.7536)
    static let tartu=WeatherArea(name:"Tartu",latitude:58.378,longitude:26.729)
    static let parnu=WeatherArea(name:"Pärnu",latitude:58.386,longitude:24.497)
}

enum WeatherKind: String { case neutral, clear, cloud, rain, snow, fog
    var symbol: String { switch self { case .neutral:return "cloud"; case .clear:return "sun.max"; case .cloud:return "cloud"; case .rain:return "cloud.rain"; case .snow:return "cloud.snow"; case .fog:return "cloud.fog" } }
    var label: String { rawValue == "neutral" ? "Weather unavailable" : rawValue.capitalized }
    static func from(code:Int) -> Self { switch code { case 0,1:return .clear; case 2,3:return .cloud; case 45,48:return .fog; case 71...77,85,86:return .snow; case 51...67,80...82,95...99:return .rain; default:return .neutral } }
}

struct WeatherSnapshot: Codable {
    var areaID: String
    var fetched: Date
    var temperature: Double
    var code: Int
    var wind: Double
    var sunrise: Date?
    var sunset: Date?
    var kind: WeatherKind { .from(code:code) }
}

@MainActor final class WeatherService: ObservableObject {
    @Published private(set) var area: WeatherArea?
    @Published private(set) var snapshot: WeatherSnapshot?
    @Published private(set) var status="Choose a weather area"
    @Published private(set) var loading=false
    private var fetchTask: Task<Void,Never>?
    private var requestID=UUID()
    init() {
        if let d=UserDefaults.standard.data(forKey:"weather.area") { area=try? JSONDecoder().decode(WeatherArea.self,from:d) }
        if let d=UserDefaults.standard.data(forKey:"weather.cache") { snapshot=try? JSONDecoder().decode(WeatherSnapshot.self,from:d) }
        if let area, snapshot?.areaID != area.id { snapshot=nil }
        if area != nil { status="Saved weather area" }
    }
    func freshness(at date:Date = Date()) -> WeatherFreshness {
        guard let snapshot else { return .expired }
        return .evaluate(age:date.timeIntervalSince(snapshot.fetched),sameArea:snapshot.areaID == area?.id)
    }
    func select(_ area: WeatherArea) {
        guard area.latitude.isFinite,area.longitude.isFinite,abs(area.latitude)<=90,abs(area.longitude)<=180 else { return }
        fetchTask?.cancel(); snapshot=nil; self.area=area
        UserDefaults.standard.set(try? JSONEncoder().encode(area),forKey:"weather.area")
        UserDefaults.standard.removeObject(forKey:"weather.cache"); refresh(force:true)
    }
    func refresh(force:Bool = false) {
        guard let area, !loading || force else { return }
        if !force, let snapshot, snapshot.areaID == area.id, Date().timeIntervalSince(snapshot.fetched)<1800 { return }
        fetchTask?.cancel();let generation=UUID();requestID=generation; loading=true; status="Updating weather…"
        fetchTask=Task {
            defer { if self.requestID == generation { self.loading=false } }
            do {
                var c=URLComponents(string:"https://api.open-meteo.com/v1/forecast")!
                c.queryItems=[.init(name:"latitude",value:String(area.latitude)),.init(name:"longitude",value:String(area.longitude)),.init(name:"current",value:"temperature_2m,weather_code,wind_speed_10m"),.init(name:"daily",value:"sunrise,sunset"),.init(name:"timeformat",value:"unixtime"),.init(name:"timezone",value:"UTC"),.init(name:"forecast_days",value:"1")]
                var request=URLRequest(url:c.url!); request.timeoutInterval=15
                let (data,response)=try await URLSession.shared.data(for:request)
                try Task.checkCancellation()
                guard self.requestID == generation else{return}
                guard (response as? HTTPURLResponse)?.statusCode == 200, self.area?.id == area.id else { throw DiagnosticError.invalid("Weather unavailable") }
                let result=try JSONDecoder().decode(WeatherAPI.self,from:data)
                guard result.current.temperature_2m.isFinite,result.current.wind_speed_10m.isFinite else { throw DiagnosticError.invalid("Weather unavailable") }
                let value=WeatherSnapshot(areaID:area.id,fetched:Date(),temperature:result.current.temperature_2m,code:result.current.weather_code,wind:result.current.wind_speed_10m,sunrise:result.daily.sunrise.first.map{Date(timeIntervalSince1970:$0)},sunset:result.daily.sunset.first.map{Date(timeIntervalSince1970:$0)})
                snapshot=value; status="Updated just now"
                UserDefaults.standard.set(try? JSONEncoder().encode(value),forKey:"weather.cache")
            } catch is CancellationError {} catch {
                guard self.area?.id == area.id,self.requestID == generation else { return }
                status=snapshot == nil ? "Weather offline" : "Showing saved weather"
            }
        }
    }
}

private struct WeatherAPI: Decodable {
    struct Current:Decodable { let temperature_2m:Double; let weather_code:Int; let wind_speed_10m:Double }
    struct Daily:Decodable { let sunrise:[Double]; let sunset:[Double] }
    let current:Current; let daily:Daily
}
