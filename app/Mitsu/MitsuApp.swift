import SwiftUI

@main struct MitsuApp: App {
    @StateObject private var store = DashboardStore()
    var body: some Scene {
        WindowGroup { DashboardView().environmentObject(store).preferredColorScheme(store.isDark ? .dark : .light) }
    }
}
