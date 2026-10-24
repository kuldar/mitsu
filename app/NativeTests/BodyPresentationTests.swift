import XCTest
import RealityKit
#if targetEnvironment(macCatalyst)
@testable import MitsuPreview
#else
@testable import Mitsu
#endif

@MainActor final class BodyPresentationTests:XCTestCase {
    func testEveryQueuedDiagnosticReservesTheTestKitAndStopClearsIt() {
        let session=DiagnosticSession(bluetooth:BluetoothClient())
        let checks:[DiagnosticSession.Check] = [.codes,.steering,.bodyIdentity,.bodyData("doors closed"),.controls(.init(kind:.climate,observation:"baseline"))]
        for check in checks {
            XCTAssertFalse(session.diagnosticCheckBusy)
            XCTAssertTrue(session.enqueue(check))
            XCTAssertTrue(session.diagnosticCheckBusy)
            for other in checks{XCTAssertFalse(session.enqueue(other),"An occupied capture must reject every additional request")}
            session.stop()
            XCTAssertFalse(session.diagnosticCheckBusy)
        }
        XCTAssertTrue(session.enqueue(.controls(.init(kind:.climate,observation:"original"))))
        XCTAssertFalse(session.enqueue(.controls(.init(kind:.preferences,observation:"replacement"))))
        XCTAssertEqual(session.requestControls?.kind,.climate)
        XCTAssertEqual(session.requestControls?.observation,"original")
    }
    func testDefaultCarLoadsWithoutPrivateModel()async throws {
        let car=try await OutlanderAsset.load()
        XCTAssertNotNil(car.findEntity(named:"wheel_FL"))
        XCTAssertGreaterThan(car.visualBounds(relativeTo:nil).extents.x,1)
        XCTAssertTrue(OutlanderAsset.readyDescription.hasPrefix("Vehicle model ready"))
    }
    private func makeArticulationFixture()->Entity {
        let root=Entity()
        let door=Entity();door.name="door_FL";root.addChild(door)
        let lamp=Entity();lamp.name="Lamp_lowBeam"
        var material=PhysicallyBasedMaterial();material.emissiveIntensity=0
        lamp.addChild(ModelEntity(mesh:.generateBox(size:0.05),materials:[material]));root.addChild(lamp)
        return root
    }
    func testBodyIdentityProbeRestoresEngineRouteAfterNegativeReply()async throws {
        var commands:[String]=[]
        let report=try await BodyIdentityProbe.run(send:{command in
            commands.append(command)
            return command == "1A87" ? "504 03 7F 1A 22":"OK"
        },isParked:{true})
        XCTAssertEqual(commands.suffix(3),["ATFCSM0","ATSH7DF","ATAR"])
        XCTAssertEqual(commands.filter{$0.hasPrefix("1A")},["1A87"])
        XCTAssertTrue(report.replies.isEmpty)
        XCTAssertEqual(report.attempts.count,1)
    }
    func testUnparkedProbeSendsNothing()async {
        var count=0
        do{_=try await BodyIdentityProbe.run(send:{_ in count += 1;return "OK"},isParked:{false});XCTFail("Must reject unparked check")}
        catch{}
        XCTAssertEqual(count,0)
    }
    func testBodyPreviewArticulationAndLampReset()async throws {
        let model=makeArticulationFixture()
        let lamp=try XCTUnwrap(model.findEntity(named:"Lamp_lowBeam"))
        let mesh=try XCTUnwrap(lamp.children.first as? ModelEntity)
        let original=try XCTUnwrap(mesh.model?.materials.first as? PhysicallyBasedMaterial)
        let renderer=VehicleBodyRenderer(model:model)
        let door=try XCTUnwrap(model.findEntity(named:"door_FL"))
        let rest=door.orientation
        renderer.update(values:[.doorFL:true,.lowBeam:true,.indicatorLeft:true],preview:true,reducedMotion:true)
        XCTAssertGreaterThan(simd_length(door.orientation.vector-rest.vector),0.2)
        let material=try XCTUnwrap(mesh.model?.materials.first as? PhysicallyBasedMaterial)
        XCTAssertGreaterThan(material.emissiveIntensity,original.emissiveIntensity)
        renderer.update(values:[:],preview:false,reducedMotion:true)
        XCTAssertLessThan(simd_length(door.orientation.vector-rest.vector),0.001)
        let restored=try XCTUnwrap(mesh.model?.materials.first as? PhysicallyBasedMaterial)
        XCTAssertEqual(restored.emissiveIntensity,original.emissiveIntensity)
    }
    func testBodyProbeCannotCompleteWhenRouteRestoreFails()async {
        var commands:[String]=[]
        do {
            _=try await BodyIdentityProbe.run(send:{command in
                commands.append(command)
                if command == "ATAR"{throw DiagnosticError.invalid("Not acknowledged")}
                return command == "1A87" ? "504 03 7F 1A 22":"OK"
            },isParked:{true})
            XCTFail("Engine polling must not resume after an unacknowledged restore")
        } catch{}
        XCTAssertEqual(commands.last,"ATAR")
    }
    func testCancelledBodyProbeDoesNotSendSecondIdentityRead()async {
        var commands:[String]=[]
        do {
            _=try await BodyIdentityProbe.run(send:{command in
                commands.append(command)
                if command == "1A87"{throw CancellationError()}
                return "OK"
            },isParked:{true})
            XCTFail("Cancelled transport cannot complete the probe")
        } catch{}
        XCTAssertFalse(commands.contains("1A9C"))
    }
    func testBoundedBodyProbeHandlesSlowRepliesAndExpires()async throws {
        var clock:TimeInterval=100
        let report=try await BodyIdentityProbe.run(send:{command in
            if command == "1A87"{clock += 4;return "504 03 5A 87 04"}
            if command == "1A9C"{return "504 03 5A 9C 01"}
            return "OK"
        },isParked:{true},now:{clock})
        XCTAssertEqual(report.replies.count,2,"A still-parked check must survive expiration of its initial speed sample")
        clock=100
        var sent:[String]=[]
        do {
            _=try await BodyIdentityProbe.run(send:{command in
                sent.append(command)
                if command == "1A87"{clock += 13;return "504 03 5A 87 04"}
                return "OK"
            },isParked:{true},now:{clock})
            XCTFail("Elapsed probe budget must stop further requests")
        }catch{}
        XCTAssertFalse(sent.contains("1A9C"))
    }
}
