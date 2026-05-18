import SwiftUI

struct MainTabView: View {
    @StateObject private var snapshotStore = CalculationSnapshotStore()
    @StateObject private var aiSettings = AISettings()
    @StateObject private var subscriptionManager = SubscriptionManager()

    var body: some View {
        Group {
            if !subscriptionManager.hasCompletedInitialLoad {
                ZStack {
                    Color(UIColor.systemGroupedBackground)
                        .ignoresSafeArea()
                    ProgressView("Preparando Materiales Obra Pro…")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if subscriptionManager.isSubscribed {
                mainTabs
            } else {
                SubscriptionGateView()
                    .environmentObject(subscriptionManager)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var mainTabs: some View {
        TabView {
            ContentView()
                .environmentObject(snapshotStore)
                .tabItem {
                    Label("Cálculos", systemImage: "hammer.fill")
                }

            NavigationView {
                AssistantView()
                    .environmentObject(aiSettings)
                    .environmentObject(snapshotStore)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("Asistente IA", systemImage: "bubble.left.and.bubble.right.fill")
            }

            NavigationView {
                SettingsView()
                    .environmentObject(aiSettings)
                    .environmentObject(subscriptionManager)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Label("Ajustes", systemImage: "gearshape.fill")
            }
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
