import Darwin
import SwiftUI

@main
struct LiquidFramesApp: App {
    init() {
        if let exitCode = AgentCommandLine.runIfRequested() {
            Darwin.exit(exitCode)
        }
    }

    var body: some Scene {
        WindowGroup {
            PrototypeRootView()
                .frame(minWidth: 1040, minHeight: 720)
        }
    }
}
