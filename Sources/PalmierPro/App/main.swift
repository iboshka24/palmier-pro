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

FileHandle.standardError.write(Data("""
Palmier Pro core: Linux/Windows build.
The editor UI, media pipeline, and MCP server are macOS-only in this phase.
See docs/Porting.md.

""".utf8))
#endif
