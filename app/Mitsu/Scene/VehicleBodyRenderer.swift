import RealityKit
import UIKit

/// Applies source-qualified body values. Unknown values use a neutral illustration;
/// they are never described as closed/off telemetry. No diagnostic writes occur here.
@MainActor final class VehicleBodyRenderer {
    private struct Panel {let entity:Entity;let rest:simd_quatf;let axis:SIMD3<Float>;let angle:Float;var current:Float=0}
    private struct Lamp {let entity:ModelEntity;let original:[any Material];let lit:[any Material];let signal:BodySignal;var amount:Float = -1}
    private var panels:[BodySignal:Panel]=[:]
    private var lamps:[Lamp]=[]
    private var beams:[SpotLight]=[]
    private var values:[BodySignal:Bool]=[:]
    private var preview=false
    private var reducedMotion=false
    private var elapsed:Float=0
    private var beamPower:Float = -1

    init(model:Entity){
        for (signal,name,angle,axis):(BodySignal,String,Float,SIMD3<Float>) in [
            (.doorFL,"door_FL",-0.80,[0,1,0]),(.doorFR,"door_FR",0.80,[0,1,0]),
            (.doorRL,"door_RL",-0.72,[0,1,0]),(.doorRR,"door_RR",0.72,[0,1,0]),
            (.tailgate,"tailgate",-1.05,[1,0,0])
        ]{
            if let entity=model.findEntity(named:name){panels[signal]=Panel(entity:entity,rest:entity.orientation,axis:axis,angle:angle)}
        }
        visit(model,lamp:nil)
        for x:Float in [-0.695,0.695]{
            let light=SpotLight()
            light.light.color=UIColor(red:1,green:0.96,blue:0.86,alpha:1)
            light.light.attenuationRadius=6
            light.light.innerAngleInDegrees=14;light.light.outerAngleInDegrees=48
            model.addChild(light)
            light.look(at:[x,0.02,-5.5],from:[x,0.79,-1.92],relativeTo:model)
            light.isEnabled=false;beams.append(light)
        }
    }
    private func visit(_ entity:Entity,lamp:BodySignal?){
        let signal=entity.name.hasPrefix("Lamp_") ? BodySignal(rawValue:String(entity.name.dropFirst(5))) : lamp
        if let signal,let model=entity as? ModelEntity,let component=model.model {
            let color:UIColor = [.indicatorLeft,.indicatorRight].contains(signal) ? UIColor(red:1,green:0.32,blue:0.015,alpha:1):signal == .brake ? UIColor(red:1,green:0.015,blue:0.005,alpha:1):UIColor(red:1,green:0.96,blue:0.83,alpha:1)
            let lit:[any Material]=component.materials.map{original in
                var material=(original as? PhysicallyBasedMaterial) ?? PhysicallyBasedMaterial()
                material.baseColor = .init(tint:color)
                material.emissiveColor = .init(color:color)
                material.emissiveIntensity=3
                material.blending = .opaque
                material.roughness = .init(floatLiteral:0.22)
                return material
            }
            lamps.append(Lamp(entity:model,original:component.materials,lit:lit,signal:signal))
        }
        for child in entity.children{visit(child,lamp:signal)}
    }
    func update(values:[BodySignal:Bool],preview:Bool,reducedMotion:Bool){
        self.values=values;self.preview=preview;self.reducedMotion=reducedMotion
        advance(0,animate:!reducedMotion)
    }
    func advance(_ delta:Float,animate:Bool){
        let dt=min(max(delta,0),0.05)
        if animate{elapsed += dt}
        for signal in Array(panels.keys){
            guard var panel=panels[signal] else{continue}
            let target=values[signal] == true ? panel.angle:0
            guard panel.current != target else{continue}
            panel.current = !animate || reducedMotion ? target:panel.current+(target-panel.current)*min(1,dt*10)
            if abs(panel.current-target)<0.0005{panel.current=target}
            panel.entity.orientation=panel.rest*simd_quatf(angle:panel.current,axis:panel.axis)
            panels[signal]=panel
        }
        let blinkOn = !preview || reducedMotion || !animate || elapsed.truncatingRemainder(dividingBy:1)<0.5
        for index in lamps.indices{
            let signal=lamps[index].signal
            var amount:Float=values[signal] == true ? 1:0
            if signal == .lowBeam,values[.highBeam] == true{amount=1}
            if signal == .brake,amount==0,values[.positionLights] == true{amount=0.25}
            if [.indicatorLeft,.indicatorRight].contains(signal),!blinkOn{amount=0}
            guard lamps[index].amount != amount else{continue}
            lamps[index].amount=amount
            if amount==0{lamps[index].entity.model?.materials=lamps[index].original}
            else {
                lamps[index].entity.model?.materials=lamps[index].lit.map{original in
                    guard var material=original as? PhysicallyBasedMaterial else{return original}
                    material.emissiveIntensity=3*amount
                    return material
                }
            }
        }
        let high=values[.highBeam] == true,low=values[.lowBeam] == true
        let power:Float=high ? 900:low ? 450:0
        if beamPower != power{
            beamPower=power
            for beam in beams{beam.isEnabled=power>0;beam.light.intensity=power}
        }
    }
}
