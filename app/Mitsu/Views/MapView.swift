import SwiftUI
import MapKit

struct DashboardMapView:View {
    @EnvironmentObject var store:DashboardStore
    @State private var position:MapCameraPosition = .region(MKCoordinateRegion(center:CLLocationCoordinate2D(latitude:59.437,longitude:24.7536),span:MKCoordinateSpan(latitudeDelta:0.08,longitudeDelta:0.12)))
    @State private var centre=CLLocationCoordinate2D(latitude:59.437,longitude:24.7536)
    var p:Palette{store.palette}
    var body:some View{
        VStack(spacing:0){
            Map(position:$position){
                if let area=store.weather.area{Marker("Weather area · "+area.name,systemImage:"cloud",coordinate:CLLocationCoordinate2D(latitude:area.latitude,longitude:area.longitude)).tint(p.accentInk)}
                if let l=store.location.location,abs(l.timestamp.timeIntervalSince(store.now))<30{Marker("Approximate position",systemImage:"location.fill",coordinate:l.coordinate).tint(.blue)}
            }.mapStyle(.standard(elevation:.realistic,pointsOfInterest:.excludingAll)).mapControls{MapCompass();MapScaleView()}
                .onMapCameraChange(frequency:.onEnd){context in centre=context.region.center}
                .clipShape(RoundedRectangle(cornerRadius:18))
            HStack(spacing:18){
                VStack(alignment:.leading,spacing:5){
                    Text(store.location.status(at:store.now)).font(.system(size:12,weight:.medium))
                    Text("Browse freely · Select weather for the map centre").font(.system(size:11)).foregroundStyle(p.muted)
                }.frame(maxWidth:.infinity,alignment:.leading)
                Button{store.location.request()}label:{Image(systemName:"location").font(.system(size:18,weight:.light)).frame(width:46,height:46).background(p.inset,in:Circle())}.buttonStyle(ConsolePressStyle()).accessibilityLabel("Find position")
                Button{store.weather.select(WeatherArea(name:"Selected map area",latitude:centre.latitude,longitude:centre.longitude))}label:{Label("Weather here",systemImage:"cloud.sun").font(.system(size:12,weight:.medium)).padding(.horizontal,15).frame(height:46).background(p.inset.opacity(0.7),in:Capsule())}.buttonStyle(ConsolePressStyle())
            }.padding(.vertical,14).padding(.horizontal,6)
        }
        .onChange(of:store.location.location){_,location in if let location{position = .region(MKCoordinateRegion(center:location.coordinate,span:MKCoordinateSpan(latitudeDelta:0.02,longitudeDelta:0.03)))}}
    }
}
