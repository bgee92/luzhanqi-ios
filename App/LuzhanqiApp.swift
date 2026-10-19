import SwiftUI

@main
struct LuzhanqiApp: App {
    @State private var settings: AppSettings

    init() {
        AppFont.registerBundledFonts()
        // UI tests launch with -uiTesting to start from a clean install: no saved
        // settings and no saved game. This must run before AppSettings reads defaults.
        if CommandLine.arguments.contains("-uiTesting") {
            if let domain = Bundle.main.bundleIdentifier { UserDefaults.standard.removePersistentDomain(forName: domain) }
            GameController.deleteSave()
        }
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
    @State private var showingDemoRules = false

    var body: some View {
        HomeView(start: { game = $0 })
            .fullScreenCover(item: $game) { controller in
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
            .onAppear {
                let args = CommandLine.arguments
                guard let i = args.firstIndex(of: "-demo"), i + 1 < args.count else { return }
                if args[i + 1] == "rules" { showingDemoRules = true } else { game = GameController.demo(args[i + 1]) }
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
