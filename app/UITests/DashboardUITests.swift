import XCTest

final class DashboardUITests:XCTestCase {
    @MainActor func testBodyPreviewAndUnknownLiveState() throws {
        let app=XCUIApplication()
        app.launchArguments=["--day","--body=lowBeam,doorFL"];app.launch()
        waitForDetailedCar(app)
        XCTAssertTrue((app.otherElements["vehicle-model"].value as? String)?.contains("Body states unknown") == true)
        app.buttons["Vehicle"].tap()
        XCTAssertTrue(app.buttons["Check body controller"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["Check body controller"].isEnabled)
        XCTAssertTrue(app.buttons["Capture lights & doors"].exists)
        XCTAssertFalse(app.buttons["Capture lights & doors"].isEnabled)
        XCTAssertTrue(app.textFields["Capture observation"].exists)
        let kit=app.buttons["Parked test kit"]
        for _ in 0..<4 where !kit.isHittable{app.scrollViews.firstMatch.swipeUp()}
        kit.tap()
        XCTAssertFalse(app.buttons["Capture climate"].isEnabled)
        XCTAssertFalse(app.buttons["Capture light & lock preferences"].isEnabled)
        app.terminate()
        app.launchArguments=["--preview","--night","--body=lowBeam,highBeam,indicatorLeft,doorFL,doorRR,tailgate,brake,reverse"];app.launch()
        waitForDetailedCar(app)
        let scene=app.otherElements["vehicle-model"]
        XCTAssertTrue((scene.value as? String)?.contains("Simulated body:") == true)
        capture("body-lights-doors-front")
        let start=app.coordinate(withNormalizedOffset:CGVector(dx:0.65,dy:0.5))
        start.press(forDuration:0.1,thenDragTo:app.coordinate(withNormalizedOffset:CGVector(dx:0.28,dy:0.5)))
        capture("body-lights-doors-rear")
        app.buttons["Vehicle"].tap()
        let dipped=app.switches["Dipped headlights"]
        XCTAssertFalse(app.buttons["Capture lights & doors"].exists)
        XCTAssertFalse(app.buttons["Parked test kit"].exists)
        for _ in 0..<4 where !dipped.isHittable{app.scrollViews.firstMatch.swipeUp()}
        XCTAssertTrue(dipped.isHittable)
        capture("body-controls-before")
        XCTAssertEqual(dipped.value as? String,"1")
        dipped.tap()
        let toggled=XCTNSPredicateExpectation(predicate:NSPredicate(format:"value == %@","0"),object:dipped)
        XCTAssertEqual(XCTWaiter.wait(for:[toggled],timeout:5),.completed,dipped.debugDescription)
        capture("body-controls-after")
        app.buttons["Drive"].tap()
        waitForDetailedCar(app)
        let state=app.otherElements["vehicle-model"].value as? String ?? ""
        XCTAssertFalse(state.contains("lowBeam"))
        XCTAssertTrue(state.contains("doorFL"))
    }
    override func setUpWithError() throws {
        continueAfterFailure=false
        #if !targetEnvironment(macCatalyst)
        XCUIDevice.shared.orientation = .landscapeLeft
        #endif
    }
    @MainActor func testOfflineAndPreviewAreDistinct() throws {
        let app=XCUIApplication();app.launchArguments=["--day"];app.launch()
        XCTAssertTrue(app.staticTexts["WAITING FOR YOUR CAR"].waitForExistence(timeout:20))
        capture("offline-dashboard")
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Connection & preferences"].waitForExistence(timeout:5))
        app.switches["Simulated preview"].tap()
        app.buttons["Drive"].tap()
        XCTAssertTrue(app.staticTexts["SIMULATED SPEED"].waitForExistence(timeout:5))
        XCTAssertTrue(app.staticTexts["64"].exists)
        app.buttons["Trips"].tap()
        XCTAssertFalse(app.buttons["Start journey"].isEnabled)
        app.buttons["Vehicle"].tap()
        XCTAssertTrue(app.buttons["Read fault codes"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["Read fault codes"].isEnabled)
        capture("vehicle-preview")
    }
    @MainActor func testDayNightAndCarOrbit() throws {
        let app=XCUIApplication();app.launchArguments=["--preview","--day"];app.launch()
        XCTAssertTrue(app.staticTexts["SIMULATED SPEED"].waitForExistence(timeout:20))
        waitForDetailedCar(app)
        capture("day-dashboard")
        let start=app.coordinate(withNormalizedOffset:CGVector(dx:0.35,dy:0.5))
        let end=app.coordinate(withNormalizedOffset:CGVector(dx:0.53,dy:0.55))
        start.press(forDuration:0.1,thenDragTo:end)
        capture("orbit-dashboard")
        app.buttons["Reset car view"].tap()
        app.buttons["Switch day and night appearance"].tap()
        XCTAssertEqual(app.buttons["Switch day and night appearance"].value as? String,"Night")
        // Capture a settled initial night frame, not the theme's cross-fade.
        app.terminate()
        app.launchArguments=["--preview","--night"];app.launch()
        XCTAssertTrue(app.staticTexts["SIMULATED SPEED"].waitForExistence(timeout:20))
        waitForDetailedCar(app)
        capture("night-dashboard")
        app.buttons["Music"].tap()
        // The test device can already have an authorized Spotify account.
        let musicReady=XCTNSPredicateExpectation(predicate:NSPredicate{_,_ in
            app.staticTexts["Now playing"].exists || app.staticTexts["Connect your Spotify account"].exists
        },object:nil)
        XCTAssertEqual(XCTWaiter.wait(for:[musicReady],timeout:5),.completed)
        capture("spotify-account")
        #if !targetEnvironment(macCatalyst)
        XCUIDevice.shared.orientation = .portrait
        app.buttons["Drive"].tap()
        XCTAssertTrue(app.staticTexts["SIMULATED SPEED"].waitForExistence(timeout:5))
        capture("portrait-dashboard")
        XCUIDevice.shared.orientation = .landscapeLeft
        #endif
    }
    @MainActor private func waitForDetailedCar(_ app:XCUIApplication){
        let car=app.otherElements["vehicle-model"]
        XCTAssertTrue(car.waitForExistence(timeout:10))
        XCTAssertTrue({
            let expectation=XCTNSPredicateExpectation(predicate:NSPredicate(format:"value BEGINSWITH %@", "Vehicle model ready"),object:car)
            return XCTWaiter.wait(for:[expectation],timeout:30) == .completed
        }(),"The bundled vehicle illustration must finish loading before the scene is captured")
    }
    @MainActor func testLocalWeatherScenes() throws {
        let app=XCUIApplication()
        for (weather,night) in [("clear",false),("cloud",false),("rain",false),("snow",false),("fog",false),("clear",true)] {
            app.launchArguments=["--preview",night ? "--night":"--day","--weather="+weather]
            app.launch()
            waitForDetailedCar(app)
            let scene=app.otherElements["vehicle-model"]
            let expected="Local \(weather) \(night ? "night":"day") ready"
            let ready=XCTNSPredicateExpectation(predicate:NSPredicate(format:"value CONTAINS %@",expected),object:scene)
            XCTAssertEqual(XCTWaiter.wait(for:[ready],timeout:20),.completed,"Local ground and matching weather must finish loading")
            XCTAssertTrue(app.staticTexts["Illustrative surroundings"].exists)
            capture("local-\(weather)-\(night ? "night":"day")")
            app.terminate()
        }
    }
    @MainActor func testCockpitNavigationAndScreens() throws {
        let app=XCUIApplication();app.launchArguments=["--preview","--day"];app.launch()
        waitForDetailedCar(app)
        XCTAssertTrue(app.buttons["Open engine details"].waitForExistence(timeout:5))
        app.buttons["Open engine details"].tap()
        XCTAssertTrue(app.staticTexts["Engine & diagnostics"].waitForExistence(timeout:5))
        for tab in ["Vehicle","Trips","Map","Music","Settings","Drive"] {
            app.buttons[tab].tap()
            XCTAssertTrue(app.staticTexts["page-title"].waitForExistence(timeout:5))
            XCTAssertEqual(app.staticTexts["page-title"].label,tab == "Drive" ? "OUTLANDER":tab)
            capture("polished-"+tab.lowercased()+"-day")
        }
        app.buttons["Switch day and night appearance"].tap()
        XCTAssertEqual(app.buttons["Switch day and night appearance"].value as? String,"Night")
        capture("polished-drive-night")
        for tab in ["Vehicle","Trips","Map","Music","Settings"] {
            app.buttons[tab].tap()
            capture("polished-"+tab.lowercased()+"-night")
        }
        #if !targetEnvironment(macCatalyst)
        XCUIDevice.shared.orientation = .portrait
        for tab in ["Drive","Vehicle","Trips","Map","Music","Settings"] {
            app.buttons[tab].tap()
            XCTAssertEqual(app.staticTexts["page-title"].label,tab == "Drive" ? "OUTLANDER":tab)
            capture("polished-"+tab.lowercased()+"-portrait")
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        #endif
    }
    @MainActor private func capture(_ name:String){
        // Settle the short theme/symbol transitions before visual comparison.
        Thread.sleep(forTimeInterval:0.35)
        let a=XCTAttachment(screenshot:XCUIScreen.main.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)
    }
}
