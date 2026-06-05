//
//  heymaxApp.swift
//  heymax
//
//  Menubar-only macOS app. No dock icon, no main window.
//  Global hotkey: Option+Space to trigger listening.

import SwiftUI
import Carbon.HIToolbox

@main
struct heymaxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var voiceEngine: VoiceEngine!
    var overlayWindow: OverlayWindow?
    var hotKeyRef: EventHotKeyRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Menubar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Hey Max")
            button.image?.size = NSSize(width: 18, height: 18)
            button.action = #selector(togglePopover)
        }

        // Popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MenubarView())
        self.popover = popover

        // Voice engine
        voiceEngine = VoiceEngine.shared

        // Overlay
        overlayWindow = OverlayWindow()

        // Register global hotkey: Option + Space
        registerHotKey()
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - Global Hotkey (Option + Space)

    private func registerHotKey() {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x484D5858) // "HMXX"
        hotKeyID.id = 1

        let modifiers: UInt32 = UInt32(optionKey)
        let keyCode: UInt32 = 49 // Space

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        // Install handler
        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            DispatchQueue.main.async {
                let voice = VoiceEngine.shared
                if voice.isListening {
                    // Simulate wake word — go straight to listening for command
                    voice.triggerManually()
                } else {
                    // Start listening first, then trigger
                    voice.requestPermissions { granted in
                        if granted {
                            voice.startListening()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                voice.triggerManually()
                            }
                        }
                    }
                }
            }
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, nil)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        print("[HeyMax] Global hotkey registered: Option+Space")
    }
}
