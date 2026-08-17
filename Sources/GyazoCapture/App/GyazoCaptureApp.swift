import SwiftUI

@main
struct GyazoCaptureApp: App {
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        MenuBarExtra("Gyazo Capture", systemImage: "camera.viewfinder") {
            MenuBarContentView()
                .environmentObject(coordinator)
                .environmentObject(coordinator.settings)
                .onAppear { coordinator.start() }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(coordinator)
                .environmentObject(coordinator.settings)
        }
    }
}
