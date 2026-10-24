import CoreLocation

@MainActor final class LocationService: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var status="No active position"
    private let manager=CLLocationManager()
    override init() { super.init(); manager.delegate=self; manager.desiredAccuracy=kCLLocationAccuracyHundredMeters }
    func request() { manager.requestWhenInUseAuthorization(); if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways { manager.requestLocation(); status="Finding position…" } }
    func status(at date:Date)->String{if let location,abs(location.timestamp.timeIntervalSince(date))>=30{return "Previous position expired · tap Find position"};return status}
    func locationManagerDidChangeAuthorization(_ manager:CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways { manager.requestLocation() }
        else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted { status="Location permission is off"; location=nil }
    }
    func locationManager(_ manager:CLLocationManager,didUpdateLocations locations:[CLLocation]) {
        guard let p=locations.last,p.horizontalAccuracy>0,p.horizontalAccuracy<=2000,abs(p.timestamp.timeIntervalSinceNow)<30 else { status="Position is too old or imprecise"; location=nil; return }
        location=p; status="Approximate position · ±\(Int(p.horizontalAccuracy)) m"
    }
    func locationManager(_ manager:CLLocationManager,didFailWithError error:Error) { location=nil; status="Position unavailable. You can still browse the map." }
}
