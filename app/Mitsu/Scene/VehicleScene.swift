import SwiftUI
import RealityKit
import Combine
import OSLog

struct VehicleScene:UIViewRepresentable {
    var dark:Bool
    var weather:WeatherKind
    var interactive:Bool
    var reducedMotion:Bool
    var active:Bool
    var speed:Double?
    var reset:Int
    var horizontalFraming:Float=0
    var verticalFieldOfView:Float=36
    var bodyValues:[BodySignal:Bool]=[:]
    var bodyPreview=false

    func makeCoordinator()->Coordinator{Coordinator()}
    func makeUIView(context:Context)->ARView {
        let view=ARView(frame:.zero,cameraMode:.nonAR,automaticallyConfigureSession:false)
        view.renderOptions=[.disableMotionBlur,.disableDepthOfField,.disableCameraGrain]
        context.coordinator.install(view)
        return view
    }
    func updateUIView(_ view:ARView,context:Context){context.coordinator.update(self)}
    static func dismantleUIView(_ view:ARView,coordinator:Coordinator){
        coordinator.updateSubscription?.cancel()
        coordinator.updateSubscription=nil
        coordinator.modelTask?.cancel()
        coordinator.modelTask=nil
        coordinator.environmentTask?.cancel()
        coordinator.environmentTask=nil
        coordinator.outdoors?.setAnimating(false)
        coordinator.view=nil
        view.scene.anchors.removeAll()
    }

    @MainActor final class Coordinator:NSObject {
        weak var view:ARView?
        let anchor=AnchorEntity(world:.zero)
        let camera=PerspectiveCamera()
        let car=Entity()
        var wheels:[(entity:Entity,rest:simd_quatf)]=[]
        var modelTask:Task<Void,Never>?
        var modelReady=false
        var bodyRenderer:VehicleBodyRenderer?
        var bodyValues:[BodySignal:Bool]=[:]
        var bodyPreview=false
        var reducedMotion=false
        var environmentTask:Task<Void,Never>?
        var environmentVersion=0
        var environmentReady=false
        var outdoors:RoadsideEnvironment?
        let environment=Entity()
        let key=DirectionalLight()
        let fill=DirectionalLight()
        var yaw:Float = -0.78
        var elevation:Float = 0.23
        var distance:Float = 8.6
        var interactive=false
        var lastReset=0
        var lastDark:Bool?
        var lastWeather:WeatherKind?
        var updateSubscription:Cancellable?
        var wheelRotation:Float=0
        var speed:Double=0
        var animate=false
        var horizontalFraming:Float=0
        func install(_ view:ARView){
            self.view=view
            view.isAccessibilityElement=true
            view.accessibilityIdentifier="vehicle-model"
            view.accessibilityLabel="Black 2014 Mitsubishi Outlander, rotatable car preview"
            view.accessibilityValue="Loading vehicle illustration"
            let loading=UILabel()
            loading.text="Preparing car illustration…"
            loading.textColor = .secondaryLabel
            loading.font = .systemFont(ofSize:14,weight:.medium)
            loading.translatesAutoresizingMaskIntoConstraints=false
            view.addSubview(loading)
            NSLayoutConstraint.activate([loading.centerXAnchor.constraint(equalTo:view.centerXAnchor),loading.centerYAnchor.constraint(equalTo:view.centerYAnchor)])
            view.scene.addAnchor(anchor)
            anchor.addChild(car);anchor.addChild(environment);anchor.addChild(camera)
            key.light.intensity=6000;key.look(at:[0,0,0],from:[-3,7,-4],relativeTo:nil);anchor.addChild(key)
            key.shadow = .init()
            fill.light.intensity=700;fill.look(at:[0,0.7,0],from:[5,3,2],relativeTo:nil);anchor.addChild(fill)
            camera.camera.fieldOfViewInDegrees=36
            // Keep depth precision on the small local scene and its fade layer.
            camera.camera.near=0.1
            camera.camera.far=100
            let pan=UIPanGestureRecognizer(target:self,action:#selector(pan(_:)));view.addGestureRecognizer(pan)
            let pinch=UIPinchGestureRecognizer(target:self,action:#selector(pinch(_:)));view.addGestureRecognizer(pinch)
            let tap=UITapGestureRecognizer(target:self,action:#selector(doubleTap));tap.numberOfTapsRequired=2;view.addGestureRecognizer(tap)
            updateCamera()
            modelTask=Task { [weak self,weak loading] in
                do {
                    let model=try await OutlanderAsset.load()
                    guard !Task.isCancelled,let self,self.view != nil else{return}
                    self.car.addChild(model)
                    self.bodyRenderer=VehicleBodyRenderer(model:model)
                    self.bodyRenderer?.update(values:self.bodyValues,preview:self.bodyPreview,reducedMotion:self.reducedMotion)
                    self.wheels=["FL","FR","RL","RR"].compactMap { name in
                        guard let wheel=model.findEntity(named:"wheel_"+name) else{return nil}
                        return (wheel,wheel.orientation)
                    }
                    self.modelReady=true
                    self.updateSceneDescription()
                    loading?.removeFromSuperview()
                } catch {
                    guard !Task.isCancelled else{return}
                    self?.view?.accessibilityValue="Vehicle asset unavailable"
                    loading?.text="Car preview unavailable"
                }
            }
            updateSubscription=view.scene.subscribe(to:SceneEvents.Update.self){[weak self] event in self?.frame(Float(event.deltaTime))}
        }
        func update(_ value:VehicleScene){
            view?.isHidden = !value.active
            camera.camera.fieldOfViewInDegrees=value.verticalFieldOfView
            if horizontalFraming != value.horizontalFraming{horizontalFraming=value.horizontalFraming;updateCamera()}
            interactive=value.interactive
            bodyValues=value.bodyValues;bodyPreview=value.bodyPreview;reducedMotion=value.reducedMotion
            bodyRenderer?.update(values:bodyValues,preview:bodyPreview,reducedMotion:reducedMotion)
            updateSceneDescription()
            speed=value.speed ?? 0
            animate=value.active && !value.reducedMotion && ProcessInfo.processInfo.thermalState != .serious && ProcessInfo.processInfo.thermalState != .critical
            outdoors?.setAnimating(animate)
            if lastReset != value.reset{lastReset=value.reset;doubleTap()}
            if lastDark != value.dark || lastWeather != value.weather{
                lastDark=value.dark;lastWeather=value.weather
                buildEnvironment(dark:value.dark,weather:value.weather)
            }
        }
        func updateCamera(){
            let position=SIMD3<Float>(sin(yaw)*cos(elevation)*distance,sin(elevation)*distance+0.7,-cos(yaw)*cos(elevation)*distance)
            let right=SIMD3<Float>(-cos(yaw),0,-sin(yaw))
            camera.look(at:SIMD3<Float>(0,0.83,0)-right*horizontalFraming,from:position,relativeTo:nil)
        }
        @objc func pan(_ gesture:UIPanGestureRecognizer){guard interactive,let view else{return};let t=gesture.translation(in:view);yaw -= Float(t.x)*0.007;elevation=min(0.8,max(0.08,elevation+Float(t.y)*0.004));gesture.setTranslation(.zero,in:view);updateCamera()}
        @objc func pinch(_ gesture:UIPinchGestureRecognizer){guard interactive else{return};distance=min(11,max(5,distance/Float(gesture.scale)));gesture.scale=1;updateCamera()}
        @objc func doubleTap(){guard interactive else{return};yaw = -0.78;elevation=0.23;distance=8.6;updateCamera()}
        func buildEnvironment(dark:Bool,weather:WeatherKind){
            environmentTask?.cancel();environmentVersion += 1
            let version=environmentVersion
            environmentReady=false;updateSceneDescription()
            view?.environment.background = .color(UIColor(Palette(dark:dark).canvas))
            environmentTask=Task { [weak self] in
                do {
                    let scene=try await RoadsideEnvironment(dark:dark,weather:weather)
                    guard !Task.isCancelled,let self,self.view != nil,self.environmentVersion==version else{return}
                    self.outdoors?.setAnimating(false)
                    self.environment.children.removeAll()
                    self.environment.addChild(scene.root)
                    self.outdoors=scene;scene.setAnimating(self.animate)
                    self.view?.environment.lighting.resource=scene.lighting
                    let overcast=[WeatherKind.cloud,.rain,.snow,.fog].contains(weather)
                    self.key.light.color=dark || overcast ? UIColor(red:0.76,green:0.85,blue:1,alpha:1):UIColor(red:1,green:0.96,blue:0.87,alpha:1)
                    self.key.look(at:[0,0,0],from:dark ? [-4,8,3]:[-6,9,-4],relativeTo:nil)
                    self.key.light.intensity=dark ? 280:overcast ? 1500:6500
                    self.fill.light.intensity=dark ? 80:overcast ? 150:400
                    self.view?.environment.lighting.intensityExponent=dark ? (overcast ? -3:-2):overcast ? -0.5:-0.6
                    self.environmentReady=true;self.updateSceneDescription()
                } catch {
                    guard !Task.isCancelled else{return}
                    Logger(subsystem:"com.example.mitsu",category:"Outdoor scene").error("Outdoor assets failed: \(error.localizedDescription,privacy:.public)")
                    self?.updateSceneDescription()
                }
            }
        }
        func updateSceneDescription(){
            let car=modelReady ? OutlanderAsset.readyDescription:"Loading vehicle illustration"
            let outside=environmentReady ? "Local \(lastWeather?.rawValue ?? "neutral") \(lastDark == true ? "night":"day") ready":"Preparing local surroundings"
            let state=bodyPreview ? "Simulated body: "+bodyValues.filter{$0.value}.map{$0.key.rawValue}.sorted().joined(separator:","):bodyValues.isEmpty ? "Body states unknown":"Body readings available"
            view?.accessibilityValue=car+" · "+outside+" · "+state
        }
        func frame(_ dt:Float){
            bodyRenderer?.advance(dt,animate:animate)
            guard animate else{return}
            outdoors?.advance(dt)
            if speed>0{
                wheelRotation += Float(speed/3.6)*min(dt,0.05)/0.365
                // Rotate only the circular tyre/rim geometry, not a steering angle.
                for wheel in wheels {wheel.entity.orientation=simd_quatf(angle:-wheelRotation,axis:[1,0,0])*wheel.rest}
            }
        }
    }
}
