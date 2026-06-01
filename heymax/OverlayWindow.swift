//
//  OverlayWindow.swift
//  heymax
//
//  Floating overlay that shows listening/thinking/response states.
//  Always on top, click-through, appears near the cursor.

import SwiftUI
import Cocoa
import Combine

enum OverlayState {
    case listening
    case thinking
    case response(String)
}

class OverlayWindow: NSObject {
    static var shared: OverlayWindow?

    private var window: NSWindow?
    private let hostingView: NSHostingController<OverlayView>
    private let viewModel = OverlayViewModel()

    override init() {
        hostingView = NSHostingController(rootView: OverlayView(viewModel: viewModel))
        super.init()
        OverlayWindow.shared = self
        setupWindow()
    }

    private func setupWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 120),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.ignoresMouseEvents = false
        window.contentViewController = hostingView

        self.window = window
    }

    func show(state: OverlayState) {
        DispatchQueue.main.async {
            self.viewModel.state = state

            // Position near top-center of screen
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let x = screenFrame.midX - 170
                let y = screenFrame.maxY - 140
                self.window?.setFrameOrigin(NSPoint(x: x, y: y))
            }

            self.window?.orderFront(nil)

            // Animate in
            self.window?.alphaValue = 0
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                self.window?.animator().alphaValue = 1
            }
        }
    }

    func hide() {
        DispatchQueue.main.async {
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.2
                self.window?.animator().alphaValue = 0
            }, completionHandler: {
                self.window?.orderOut(nil)
            })
        }
    }
}

// MARK: - View Model

class OverlayViewModel: ObservableObject {
    @Published var state: OverlayState = .listening
}

// MARK: - Overlay View

struct OverlayView: View {
    @ObservedObject var viewModel: OverlayViewModel

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            statusIcon

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(3)
            }

            Spacer()
        }
        .padding(16)
        .frame(width: 340, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch viewModel.state {
        case .listening:
            ZStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 36, height: 36)
                Image(systemName: "waveform")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
        case .thinking:
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 36, height: 36)
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(.white)
            }
        case .response:
            ZStack {
                Circle()
                    .fill(Color.purple)
                    .frame(width: 36, height: 36)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }

    private var title: String {
        switch viewModel.state {
        case .listening: return "Listening..."
        case .thinking: return "Thinking..."
        case .response: return "Max"
        }
    }

    private var subtitle: String {
        switch viewModel.state {
        case .listening: return "Say your command"
        case .thinking: return "Processing your request"
        case .response(let text): return text
        }
    }
}
