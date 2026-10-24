import SwiftUI

/// A preparation workflow, kept distinct from unverified vehicle controls.
struct ParkedControlsView:View {
    @EnvironmentObject var store:DashboardStore
    @Binding var observation:String
    let unavailable:Bool
    @State private var expanded=false
    @State private var exportURL:URL?
    @State private var exportError:String?
    private var p:Palette{store.palette}
    var body:some View {
        DisclosureGroup(isExpanded:$expanded){
            VStack(alignment:.leading,spacing:14){
                Text("Use the car's own controls, then capture one change at a time. Your observation above is saved with each report.")
                    .font(.system(size:12)).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)
                ForEach(ControlsCaptureKind.allCases,id:\.self){kind in
                    Button{
                        exportURL=nil;exportError=nil
                        store.diagnostics.enqueue(.controls(.init(kind:kind,observation:observation)))
                    }label:{
                        HStack(spacing:12){
                            Image(systemName:kind == .climate ? "fan":"lock.car")
                            VStack(alignment:.leading,spacing:4){
                                Text(kind == .climate ? "Capture climate":"Capture light & lock preferences").font(.system(size:13,weight:.medium))
                                Text(kind == .climate ? "Identify the controller, then read candidate climate records":"Save the current customization record without changing it")
                                    .font(.system(size:11)).foregroundStyle(p.muted)
                            }
                            Spacer(minLength:0)
                            Image(systemName:"arrow.down.doc").font(.system(size:12))
                        }.frame(minHeight:48).frame(maxWidth:.infinity,alignment:.leading).contentShape(Rectangle())
                    }.buttonStyle(ConsolePressStyle()).disabled(unavailable).accessibilityLabel(kind == .climate ? "Capture climate":"Capture light & lock preferences")
                }
                Text(store.diagnostics.controlsStatus).font(.system(size:12)).fixedSize(horizontal:false,vertical:true)
                if let report=store.diagnostics.controlsReport {
                    Text("\(report.kind.title) · \(report.started.formatted(date:.abbreviated,time:.shortened))\(report.observation.isEmpty ? "":" · "+report.observation)")
                        .font(.system(size:11)).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)
                    if let exportURL{ShareLink(item:exportURL){Label("Share control preparation",systemImage:"square.and.arrow.up").font(.system(size:12,weight:.medium)).frame(minHeight:44)}}
                    else{Button("Prepare control report"){
                        do{
                            let documents=try FileManager.default.url(for:.documentDirectory,in:.userDomainMask,appropriateFor:nil,create:true)
                            exportURL=try report.persist(in:documents.appendingPathComponent("Diagnostics"))
                        }catch{exportError="Couldn't prepare the report. Try again."}
                    }.font(.system(size:12,weight:.medium)).frame(minHeight:44)}
                    if let exportError{Text(exportError).font(.system(size:11)).foregroundStyle(p.muted)}
                }
                Divider().overlay(p.muted.opacity(0.2))
                guide("Climate","Capture a baseline. Change only the panel temperature, fan, recirculation or outlet mode, label it and capture again. Restore the baseline and take a final capture.")
                guide("Lights & doors","Use Capture lights & doors above: baseline, low beams, high beams, left/right indicators, hazards and each door in turn. For locks, compare manual lock/unlock with the doors closed. Door-open switches don't prove lock position.")
                guide("Preferences","One capture is enough initially. It may reveal comfort flashing, coming-home lighting and locking preferences. It isn't a full ECU backup.")
                guide("Action tests still pending","Climate overrides need exact hardware matching and proven release after stopping or losing Bluetooth. A normal temperature-setting command and immediate light/lock commands are still unconfirmed. These captures never operate them.")
                Text("Stay parked until engine readings resume. Every capture is kept on the iPad; share each changed state while it is the latest report.")
                    .font(.system(size:11)).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)
            }.padding(.top,12)
        }label:{Label("Parked test kit",systemImage:"checklist").font(.system(size:14,weight:.medium))}
        .tint(p.accentInk)
        .onChange(of:store.diagnostics.controlsReport?.started){_,_ in exportURL=nil;exportError=nil}
    }
    private func guide(_ title:String,_ text:String)->some View {
        VStack(alignment:.leading,spacing:5){Text(title).font(.system(size:12,weight:.semibold));Text(text).font(.system(size:11)).foregroundStyle(p.muted).fixedSize(horizontal:false,vertical:true)}
    }
}
