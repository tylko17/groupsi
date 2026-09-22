import SwiftUI

@main
struct StudyBuddyApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(state)
        } label: {
            Image(systemName: state.menuBarIcon)
            if !state.menuBarTitle.isEmpty {
                Text(state.menuBarTitle)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
