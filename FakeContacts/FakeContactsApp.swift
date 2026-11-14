import SwiftUI

@main
struct FakeContactsApp: App {
    @StateObject private var trickEngine = TrickEngine()

    var body: some Scene {
        WindowGroup {
            ContactsListView()
                .environmentObject(trickEngine)
                .preferredColorScheme(.dark)
        }
    }
}
