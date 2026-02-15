import SwiftUI

@main
struct DailyLogApp: App {
    let persistence = PersistenceController.shared
    @StateObject private var authManager = AuthenticationManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPrivacyBlur = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if authManager.isUnlocked {
                        ContentView()
                            .environment(\.managedObjectContext, persistence.viewContext)
                    } else {
                        LockScreenView()
                    }
                }

                // Privacy screen — hides content in app switcher
                if showPrivacyBlur {
                    Color(.systemBackground)
                        .overlay {
                            VStack(spacing: 12) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)
                                Text("DailyLog")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
            }
            .environmentObject(authManager)
            .onChange(of: scenePhase) { newPhase in
                switch newPhase {
                case .active:
                    withAnimation(.easeOut(duration: 0.15)) {
                        showPrivacyBlur = false
                    }
                    if !authManager.isUnlocked {
                        authManager.authenticate()
                    }
                case .inactive:
                    withAnimation(.easeIn(duration: 0.1)) {
                        showPrivacyBlur = true
                    }
                case .background:
                    showPrivacyBlur = true
                    authManager.lock()
                @unknown default:
                    break
                }
            }
            .onAppear {
                authManager.authenticate()
            }
        }
    }
}
