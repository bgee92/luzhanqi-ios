import SwiftUI

@main
struct LuzhanqiApp: App {
    @State private var settings: AppSettings

    init() {
        AppFont.registerBundledFonts()
        #if DEBUG
        // UI tests launch with -uiTesting to start from a clean install: no saved
        // settings and no saved game. This must run before AppSettings reads defaults.
        // Debug builds only, so a release build can never be told to wipe its data.
        if CommandLine.arguments.contains("-uiTesting") {
            if let domain = Bundle.main.bundleIdentifier { UserDefaults.standard.removePersistentDomain(forName: domain) }
            GameController.deleteSave()
        }
        #endif
        _settings = State(initialValue: AppSettings())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(settings)
                .environment(\.locale, settings.language.locale)
                .tint(Palette.red)
        }
    }
}

struct ContentView: View {
    @Environment(AppSettings.self) private var settings
    @State private var game: GameController?
    @State private var hasSave = GameController.hasSave
    @State private var showingDemoRules = false
    @State private var showingDemoSettings = false

    var body: some View {
        HomeView(start: { game = $0 }, hasSave: hasSave)
            // A game that was saved and quit can be resumed straight away.
            .fullScreenCover(item: $game, onDismiss: { hasSave = GameController.hasSave }) { controller in
                GameFlowView(controller: controller, close: { game = nil }, rematch: {
                    game = GameController(mode: controller.mode, rules: controller.rules)
                })
                .environment(settings)
                .environment(\.locale, settings.language.locale)
                // Game screens are paper, whatever the phone's appearance setting.
                .preferredColorScheme(.light)
            }
            #if DEBUG
            .sheet(isPresented: $showingDemoRules) { NavigationStack { RulesView() }.preferredColorScheme(.light) }
            .sheet(isPresented: $showingDemoSettings) { SettingsView().preferredColorScheme(.light) }
            .onAppear {
                let args = CommandLine.arguments
                guard let i = args.firstIndex(of: "-demo"), i + 1 < args.count else { return }
                switch args[i + 1] {
                case "rules": showingDemoRules = true
                case "settings": showingDemoSettings = true
                default: game = GameController.demo(args[i + 1])
                }
            }
            #endif
    }
}

/// Routes a game to the screen for its current phase.
struct GameFlowView: View {
    let controller: GameController
    let close: () -> Void
    let rematch: () -> Void

    var body: some View {
        switch controller.phase {
        case let .deploying(side):
            DeploymentView(controller: controller, side: side, close: close)
        case let .handoff(side):
            HandoffView(side: side, isDeployment: controller.state == nil) { controller.acceptHandoff() }
        case .playing, .turnComplete, .over:
            GameView(controller: controller, close: close, rematch: rematch)
        }
    }
}
