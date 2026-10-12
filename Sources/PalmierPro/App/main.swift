#if os(macOS)
import AppKit

Log.bootstrap()
Telemetry.start()
Analytics.start()
Analytics.capture(.appOpened)
BundledFonts.register()
AccountService.shared.configure()
ModelCatalog.shared.configure()

// Shorten the default tooltip delay from 2s to 0.01s.
UserDefaults.standard.set(10, forKey: "NSInitialToolTipDelay")

let app = NSApplication.shared
AppAppearanceStore.shared.apply()
let delegate = AppDelegate.shared
app.delegate = delegate
app.mainMenu = MainMenuBuilder.buildMenu()
app.run()
#else
import Foundation

// Linux/Windows: serve the portable core + timeline UI.
// Flags: --port N (preferred port), --no-browser.
var preferredPort = PortServer.preferredPort
var openBrowser = true
var args = Array(CommandLine.arguments.dropFirst())
while !args.isEmpty {
    let arg = args.removeFirst()
    switch arg {
    case "--port":
        if let value = args.first.flatMap({ Int($0) }) {
            preferredPort = value
            _ = args.removeFirst()
        }
    case "--no-browser":
        openBrowser = false
    case "--help", "-h":
        print("""
        Palmier Pro (portable core)

        Usage: PalmierPro [--port N] [--no-browser]

        Serves the timeline UI at http://127.0.0.1:<port>/ and opens it
        in the default browser. See docs/Porting.md.

        """)
        exit(0)
    default:
        FileHandle.standardError.write(Data("unknown argument: \(arg)\n".utf8))
        exit(2)
    }
}

do {
    try PortServer.start(preferredPort: preferredPort, openBrowser: openBrowser)
} catch {
    FileHandle.standardError.write(Data("port server failed: \(error)\n".utf8))
    exit(1)
}
#endif
