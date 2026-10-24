import XCTest
import SwiftUI
import RealityKit
#if targetEnvironment(macCatalyst)
@testable import MitsuPreview
#else
@testable import Mitsu
#endif

@MainActor final class DashboardPresentationTests:XCTestCase {
    func testNewlyReceivedLiveReadingIsVisibleBetweenTimerTicks() {
        let store=DashboardStore()
        // The UI timer cannot advance on the main thread during this interval.
        Thread.sleep(forTimeInterval:0.025)
        let sample=Sample(signal:.coolant,value:84,ecu:"7E8",uptime:ProcessInfo.processInfo.systemUptime,source:.live)
        store.snapshot.samples[.coolant]=sample
        XCTAssertEqual(store.snapshot.value(.coolant,at:store.uptime,connected:true,preview:false),84,
                       "A freshly received reading must not disappear until the next UI timer tick")
    }

    func testPresentationClockStillRejectsFutureSamples() {
        let store=DashboardStore()
        store.snapshot.samples[.coolant]=Sample(signal:.coolant,value:84,ecu:"7E8",uptime:ProcessInfo.processInfo.systemUptime+10,source:.live)
        XCTAssertNil(store.snapshot.value(.coolant,at:store.uptime,connected:true,preview:false))
    }

    func testRotationSizesPreserveTheVehicleRenderer() async throws {
        let store=DashboardStore()
        let host=UIHostingController(rootView:DriveView().environmentObject(store))
        let scene=try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window=UIWindow(windowScene:scene)
        window.frame=CGRect(x:0,y:0,width:1000,height:580)
        window.rootViewController=host
        window.makeKeyAndVisible()
        defer{window.isHidden=true;window.rootViewController=nil}
        host.view.layoutIfNeeded()
        try await settle()
        let original=try XCTUnwrap(renderer(in:host.view))
        // Rotation can pass through a short intermediate size before becoming tall.
        for size in [CGSize(width:700,height:580),CGSize(width:700,height:1000),CGSize(width:1000,height:580)] {
            window.frame=CGRect(origin:.zero,size:size)
            host.view.setNeedsLayout();host.view.layoutIfNeeded()
            try await settle()
            XCTAssertTrue(renderer(in:host.view) === original,"Resizing must preserve the scene and its camera instead of loading it again")
        }
    }

    private func settle()async throws{try await Task.sleep(for:.milliseconds(120))}
    private func renderer(in view:UIView)->ARView? {
        if let renderer=view as? ARView{return renderer}
        for child in view.subviews{if let found=renderer(in:child){return found}}
        return nil
    }
}
