import SwiftUI

@main
struct DailyLogApp: App {
    let persistence = PersistenceController.shared
    @StateObject private var authManager = AuthenticationManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isUnlocked {
                    ContentView()
                        .environment(\.managedObjectContext, persistence.viewContext)
                } else {
                    LockScreenView()
                }
            }
            .environmentObject(authManager)
            .onChange(of: scenePhase) { newPhase in
                switch newPhase {
                case .active:
                    if !authManager.isUnlocked {
                        authManager.authenticate()
                    }
                case .background:
                    authManager.lock()
                default:
                    break
                }
            }
            .onAppear {
                authManager.authenticate()
            }
        }
    }
}
