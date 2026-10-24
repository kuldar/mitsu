import SwiftUI

struct VehicleBodyView:View {
    @EnvironmentObject var store:DashboardStore
    @State private var exportURL:URL?
    @State private var exportError:String?
    @State private var dataExportURL:URL?
    @State private var dataExportError:String?
    @State private var observation=""
    var p:Palette{store.palette}
    var bodyCheckUnavailable:Bool {
        !store.parked || store.value(.speed) != 0 || !store.diagnostics.live || store.diagnostics.diagnosticCheckBusy
    }
    var body:some View {
        VStack(alignment:.leading,spacing:18){
            ConsoleRule(palette:p)
            HStack{SectionHeading(title:"Lights & body",subtitle:store.preview ? "Simulated model states":"Live body signals need validation",palette:p);Spacer();Image(systemName:"car.side.front.open").font(.system(size:28,weight:.light)).foregroundStyle(p.muted)}
            if store.preview {
                Text("Explore the model here. These switches only change the preview.").font(.system(size:12)).foregroundStyle(p.muted)
                LazyVGrid(columns:[GridItem(.adaptive(minimum:240),spacing:28)],alignment:.leading,spacing:4){
                    ForEach(BodySignal.allCases.filter{![BodySignal.wipers,.rearFog].contains($0)},id:\.self){signal in
                        Toggle(isOn:Binding(get:{store.previewBody.contains(signal)},set:{on in
                            if on{store.previewBody.insert(signal)}else{store.previewBody.remove(signal)}
                        })){
                            Text(signal == .positionLights ? "Tail lights":signal.title)
                                .frame(maxWidth:.infinity,alignment:.leading).contentShape(Rectangle())
                                .onTapGesture{if store.previewBody.contains(signal){store.previewBody.remove(signal)}else{store.previewBody.insert(signal)}}
                        }.font(.system(size:13)).tint(p.accentInk).frame(minHeight:44).disabled(!OutlanderAsset.hasCustomModel && ![BodySignal.lowBeam,.highBeam].contains(signal))
                    }
                }
                Text("The bundled procedural car supports beam illumination. Other model animations require an optional articulated asset; window and wiper animation is not implemented.").font(.system(size:11)).foregroundStyle(p.muted)
            } else {
                HStack(alignment:.top,spacing:22){
                    ForEach(["Headlights","Indicators","Doors"],id:\.self){name in
                        VStack(alignment:.leading,spacing:8){Text(name).font(.system(size:12)).foregroundStyle(p.muted);Text("Unknown").font(.system(size:23,weight:.light))}.frame(maxWidth:.infinity,alignment:.leading)
                    }
                }.accessibilityElement(children:.combine)
                Text("Experimental body reads require your own locally configured controller identity. Their values still need comparing with your car. The model's neutral pose does not mean the lights are off or the doors are closed.").font(.system(size:12)).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)
                TextField("Observed state, e.g. low beams on, doors closed",text:$observation).textFieldStyle(.plain).font(.system(size:13)).padding(.vertical,10).accessibilityLabel("Capture observation").onChange(of:observation){_,value in observation=String(value.prefix(160))}
                Button{dataExportURL=nil;dataExportError=nil;store.diagnostics.enqueue(.bodyData(observation))}label:{Label("Capture lights & doors",systemImage:"headlight.low.beam").font(.system(size:13,weight:.medium)).frame(minHeight:44)}.buttonStyle(ConsolePressStyle()).disabled(bodyCheckUnavailable)
                Text(store.diagnostics.bodyDataStatus).font(.system(size:12)).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)
                Text("Checks this controller's identity, then requests four light, door and switch records. It doesn't change settings or operate the car. Keep the car parked until engine readings resume.").font(.system(size:11)).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)
                if let report=store.diagnostics.bodyDataReport {
                    if !report.observation.isEmpty{Text(report.observation).font(.system(size:11)).foregroundStyle(p.muted)}
                    HStack {
                        Text("Capture \(report.started.formatted(date:.abbreviated,time:.shortened))").font(.system(size:11)).foregroundStyle(p.muted)
                        Spacer()
                        if let dataExportURL {ShareLink(item:dataExportURL){Label("Share body data",systemImage:"square.and.arrow.up").font(.system(size:12,weight:.medium)).frame(minHeight:44)}}
                        else{Button("Prepare body data"){
                            do{
                                let documents=try FileManager.default.url(for:.documentDirectory,in:.userDomainMask,appropriateFor:nil,create:true)
                                dataExportURL=try report.persist(in:documents.appendingPathComponent("Diagnostics"))
                            }catch{dataExportError="Couldn't prepare body data. Try again."}
                        }.font(.system(size:12,weight:.medium)).frame(minHeight:44)}
                    }
                    if let dataExportError{Text(dataExportError).font(.system(size:11)).foregroundStyle(p.muted)}
                }
                ParkedControlsView(observation:$observation,unavailable:bodyCheckUnavailable)
                Button{exportURL=nil;store.diagnostics.enqueue(.bodyIdentity)}label:{Label(store.diagnostics.checkingBody ? "Checking body controller…":"Check body controller",systemImage:"antenna.radiowaves.left.and.right").font(.system(size:13,weight:.medium)).frame(minHeight:44)}.buttonStyle(ConsolePressStyle())
                    .disabled(bodyCheckUnavailable)
                Text(store.diagnostics.bodyCheckStatus).font(.system(size:12)).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)
                Text("When parked and connected, this reads the controller identity and resumes engine readings. It doesn't change settings or operate the car.").font(.system(size:11)).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)
                if let report=store.diagnostics.bodyReport {
                    HStack{
                        Text("Last check \(report.started.formatted(date:.abbreviated,time:.shortened))").font(.system(size:11)).foregroundStyle(p.muted)
                        Spacer()
                        if let exportURL {ShareLink(item:exportURL){Label("Share report",systemImage:"square.and.arrow.up").font(.system(size:12,weight:.medium)).frame(minHeight:44)}}
                        else{Button("Prepare report"){do{exportURL=try report.export(to:FileManager.default.temporaryDirectory)}catch{exportError="Couldn't prepare the report. Try again."}}.font(.system(size:12,weight:.medium)).frame(minHeight:44)}
                    }
                    if let exportError{Text(exportError).font(.system(size:11)).foregroundStyle(p.muted)}
                }
            }
        }.onChange(of:store.diagnostics.bodyReport?.started){_,_ in exportURL=nil;exportError=nil}
            .onChange(of:store.diagnostics.bodyDataReport?.started){_,_ in dataExportURL=nil;dataExportError=nil}
    }
}
