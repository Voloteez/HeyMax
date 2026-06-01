//
//  ActionRunner.swift
//  heymax
//
//  Executes actions returned by Claude — open URLs, launch apps,
//  run AppleScript, control Spotify, set volume.

import Cocoa

struct ActionRunner {
    static func run(_ action: AppAction) {
        switch action {
        case .openURL(let url):
            if let u = URL(string: url) {
                NSWorkspace.shared.open(u)
                print("[Action] Opened URL: \(url)")
            }

        case .openApp(let name):
            let config = NSWorkspace.OpenConfiguration()
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID(for: name)) {
                NSWorkspace.shared.openApplication(at: appURL, configuration: config)
                print("[Action] Opened app: \(name)")
            } else {
                NSWorkspace.shared.launchApplication(name)
                print("[Action] Launched app by name: \(name)")
            }

        case .runAppleScript(let script):
            DispatchQueue.global().async {
                let proc = Process()
                proc.launchPath = "/usr/bin/osascript"
                proc.arguments = ["-e", script]
                proc.launch()
                proc.waitUntilExit()
                print("[Action] Ran AppleScript")
            }

        case .playSpotify(let query):
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            DispatchQueue.global().async {
                // Open search in Spotify
                let open = Process()
                open.launchPath = "/usr/bin/open"
                open.arguments = ["-a", "Spotify", "spotify:search:\(encoded)"]
                try? open.run()
                open.waitUntilExit()
                print("[Action] Opened Spotify search")

                Thread.sleep(forTimeInterval: 3.0)

                // Get Spotify window position and click the green play button
                let script = Process()
                let pipe = Pipe()
                script.launchPath = "/usr/bin/osascript"
                script.standardOutput = pipe
                script.arguments = ["-e", """
                    tell application "Spotify" to activate
                    delay 0.3
                    tell application "System Events"
                        tell process "Spotify"
                            set frontmost to true
                            set winPos to position of window 1
                            set winSize to size of window 1
                            return (item 1 of winPos) & "," & (item 2 of winPos) & "," & (item 1 of winSize) & "," & (item 2 of winSize)
                        end tell
                    end tell
                """]
                try? script.run()
                script.waitUntilExit()

                let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let parts = output.components(separatedBy: ", ")

                if parts.count == 4,
                   let winX = Double(parts[0]),
                   let winY = Double(parts[1]),
                   let winW = Double(parts[2]) {
                    // The green play button on the top result card
                    let clickX = winX + winW * 0.62
                    let clickY = winY + 230

                    // Click using CGEvent
                    let point = CGPoint(x: clickX, y: clickY)
                    let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
                    let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
                    mouseDown?.post(tap: .cghidEventTap)
                    Thread.sleep(forTimeInterval: 0.05)
                    mouseUp?.post(tap: .cghidEventTap)
                    print("[Action] Clicked play button at \(clickX), \(clickY)")
                } else {
                    print("[Action] Could not get Spotify window position: \(output)")
                }
            }
            print("[Action] Playing on Spotify: \(query)")

        case .setVolume(let level):
            let clamped = max(0, min(100, level))
            let script = "set volume output volume \(clamped)"
            let proc = Process()
            proc.launchPath = "/usr/bin/osascript"
            proc.arguments = ["-e", script]
            try? proc.run()
            print("[Action] Set volume to \(clamped)%")

        case .typeText(let text):
            let escaped = text.replacingOccurrences(of: "\"", with: "\\\"")
            let script = """
            tell application "System Events"
                keystroke "\(escaped)"
            end tell
            """
            let proc = Process()
            proc.launchPath = "/usr/bin/osascript"
            proc.arguments = ["-e", script]
            try? proc.run()
            print("[Action] Typed text")
        }
    }

    // MARK: - Bundle ID Lookup

    private static func bundleID(for appName: String) -> String {
        let map: [String: String] = [
            "safari": "com.apple.Safari",
            "spotify": "com.spotify.client",
            "chrome": "com.google.Chrome",
            "slack": "com.tinyspeck.slackmacgap",
            "discord": "com.hnc.Discord",
            "notion": "notion.id",
            "figma": "com.figma.Desktop",
            "terminal": "com.apple.Terminal",
            "xcode": "com.apple.dt.Xcode",
            "finder": "com.apple.finder",
            "messages": "com.apple.MobileSMS",
            "notes": "com.apple.Notes",
            "calendar": "com.apple.iCal",
            "music": "com.apple.Music",
            "mail": "com.apple.mail",
            "vscode": "com.microsoft.VSCode",
        ]
        return map[appName.lowercased()] ?? "com.apple.\(appName)"
    }
}
