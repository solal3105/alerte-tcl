import SwiftUI
import BackgroundTasks
import Shared

private let alertRefreshIdentifier = "com.alertetcl.alert-refresh"

private func handleAlertRefresh(task: BGAppRefreshTask) {
    scheduleAlertRefresh()
    let work = Task {
        let alerts = try? await TCLAPIService.shared.fetchAlerts()
        if let alerts {
            await NotificationService.shared.processNewAlerts(
                alerts, subscriptionService: SubscriptionService.shared
            )
        }
    }
    task.expirationHandler = { work.cancel() }
    Task { await work.value; task.setTaskCompleted(success: !work.isCancelled) }
}

private func scheduleAlertRefresh() {
    let request = BGAppRefreshTaskRequest(identifier: alertRefreshIdentifier)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    try? BGTaskScheduler.shared.submit(request)
}

@main
struct AlerteTCLApp: App {
    @StateObject private var viewModel = AlertViewModel()
    @AppStorage("hasShownNotificationPrompt") private var hasShownNotificationPrompt = false
    @AppStorage("hasShownLocationPrompt") private var hasShownLocationPrompt = false
    @State private var showNotificationPrompt = false
    @State private var showLocationPrompt = false
    /// Lien profond reçu (widgets) ; ContentView le route vers le bon onglet.
    @State private var deepLink: WidgetLink?
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Couleurs officielles des lignes : rechargées avant tout accès réseau, puis
        // conservées dans le conteneur partagé à chaque mise à jour de l'index des fiches horaires.
        LinePalette.shared.restore(encoded: AppGroup.paletteStorage.string(forKey: AppGroup.linePaletteKey))
        LinePalette.shared.onChange = { encoded in
            AppGroup.paletteStorage.set(encoded, forKey: AppGroup.linePaletteKey)
            Task { @MainActor in LinePaletteObserver.shared.paletteDidChange() }
        }
        // Les widgets ne lient pas le module Kotlin : leurs couleurs et les lignes suivies leur sont publiées.
        Task { @MainActor in
            WidgetBridge.shared.publishTheme()
            WidgetBridge.shared.publishSubscriptions(SubscriptionService.shared.subscribedLineIds)
            // À chaque lancement, les widgets repartent des données du moment (et d'une nouvelle version de l'app).
            WidgetBridge.shared.reload(WidgetKind.allCases)
        }
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: alertRefreshIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handleAlertRefresh(task: refreshTask)
        }
        configureAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(deepLink: $deepLink)
                .onAppear {
                    #if DEBUG
                    // Mode démo (-demo parking) : ouvrir la fiche du P+R St-Genis
                    // (parc sans disponibilité temps réel) via le deep link parking.
                    if DemoShowcase.current == "parking" {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            deepLink = .parking("parc-relais-HLS")
                        }
                    }
                    #endif
                }
                .environmentObject(viewModel)
                .onAppear {
                    if !hasShownLocationPrompt {
                        Task {
                            try? await Task.sleep(for: .seconds(1))
                            await MainActor.run {
                                showLocationPrompt = true
                                hasShownLocationPrompt = true
                            }
                        }
                    } else if !hasShownNotificationPrompt {
                        Task {
                            try? await Task.sleep(for: .seconds(1))
                            await MainActor.run {
                                showNotificationPrompt = true
                                hasShownNotificationPrompt = true
                            }
                        }
                    }
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { scheduleAlertRefresh() }
                    // L'écran d'accueil arrive : les widgets de passages repartent de l'heure exacte.
                    if phase == .background { WidgetBridge.shared.reloadTimeSensitive() }
                }
                .sheet(isPresented: $showLocationPrompt) {
                    LocationPermissionView()
                        .onDisappear {
                            if !hasShownNotificationPrompt {
                                Task {
                                    try? await Task.sleep(for: .milliseconds(500))
                                    await MainActor.run {
                                        showNotificationPrompt = true
                                        hasShownNotificationPrompt = true
                                    }
                                }
                            }
                        }
                }
                .sheet(isPresented: $showNotificationPrompt) {
                    NotificationPermissionView()
                }
        }
    }

    private func handleDeepLink(_ url: URL) {
        guard let link = WidgetLink(url: url) else {
            AppLogger.error("Lien profond rejeté : \(url.absoluteString)", category: .app)
            return
        }
        deepLink = link
    }
    
    private func configureAppearance() {
        // Dès iOS 26, les barres sont en verre (Liquid Glass) par défaut : toute apparence forcée
        // ici les ramènerait au style opaque d'avant. On ne règle que les versions précédentes.
        if #available(iOS 26, *) { return }
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor.systemBackground
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance

        // Sans configuration explicite, iOS 15+ bascule en mode transparent
        // quand du contenu passe derrière la tab bar (.ignoresSafeArea sur la carte).
        // Ça supprime le glassmorphisme ET peut casser les zones de tap des onglets.
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground() // force le fond flouté système
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
    }
}
