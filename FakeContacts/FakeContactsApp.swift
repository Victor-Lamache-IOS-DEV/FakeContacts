import SwiftUI

@main
struct FakeContactsApp: App {
    @StateObject private var trickEngine = TrickEngine()

    var body: some Scene {
        WindowGroup {
            ContactsListView()
                .environmentObject(trickEngine)
                .preferredColorScheme(.dark)
                // iOS 26 glass window background
                .background {
                    if #available(iOS 26.0, *) {
                        Color(.systemGroupedBackground).glassEffect()
                    } else {
                        Color(.systemBackground)
                    }
                }
        }
    }
}
