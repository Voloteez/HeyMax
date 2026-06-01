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
            // Open search in Spotify app
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let proc = Process()
            proc.launchPath = "/usr/bin/open"
            proc.arguments = ["-a", "Spotify", "spotify:search:\(encoded)"]
            try? proc.run()
            print("[Action] Opened Spotify search: \(query)")

        case .searchYouTube(let query):
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let ytURL = "https://www.youtube.com/results?search_query=\(encoded)"
            // Open the search page
            if let url = URL(string: ytURL) {
                NSWorkspace.shared.open(url)
            }
            // After page loads, click the first video result via JavaScript
            DispatchQueue.global().async {
                Thread.sleep(forTimeInterval: 3.0)
                let js = "document.querySelector('ytd-video-renderer a#video-title, ytd-rich-item-renderer a#video-title-link').click();"
                // Try Chrome first, then Safari
                let chrome = Process()
                let chromePipe = Pipe()
                chrome.launchPath = "/usr/bin/osascript"
                chrome.standardError = chromePipe
                chrome.arguments = ["-e", """
                    tell application "Google Chrome"
                        execute front window's active tab javascript "\(js)"
                    end tell
                """]
                try? chrome.run()
                chrome.waitUntilExit()

                let err = String(data: chromePipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                if !err.isEmpty {
                    // Chrome didn't work, try Safari
                    let safari = Process()
                    safari.launchPath = "/usr/bin/osascript"
                    safari.arguments = ["-e", """
                        tell application "Safari"
                            do JavaScript "\(js)" in current tab of front window
                        end tell
                    """]
                    try? safari.run()
                    safari.waitUntilExit()
                }
                print("[Action] YouTube auto-play triggered")
            }

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
