import SwiftUI

@main struct SpaceMithraApp: App {
    private let launchStarted = Date()
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup {
            MainView(model: model)
                .environment(\.locale, Locale(identifier: model.language))
                .environment(\.layoutDirection, model.language == "ar" ? .rightToLeft : .leftToRight)
                .frame(minWidth: 1080, minHeight: 700)
                .task {
                    await model.start()
                    let arguments = ProcessInfo.processInfo.arguments
                    // Explicit local smoke mode uses an isolated database and never scans user files.
                    if arguments.contains("--ui-testing") && arguments.contains("--smoke-test") {
                        let deadline=Date().addingTimeInterval(10)
                        while model.scanning && Date()<deadline {try? await Task.sleep(for:.milliseconds(50))}
                        try? await Task.sleep(for: .milliseconds(250))
                        let ready = model.catalog != nil && NSApplication.shared.windows.contains { $0.isVisible }
                        print("SPACEMITHRA_SMOKE ready=\(ready) windowSeconds=\(Date().timeIntervalSince(launchStarted)) state=\(model.progress.state.rawValue) count=\(model.progress.count) root=\(model.root?.path ?? "none")")
                        NSApplication.shared.terminate(nil)
                    }
                }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button(model.text("chooseFolder")) { model.chooseFolder() }.keyboardShortcut("o")
                Button(model.text("cancel")) { model.cancel() }.keyboardShortcut(".")
            }
        }
    }
}
