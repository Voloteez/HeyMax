//
//  ScreenCapture.swift
//  heymax
//
//  Captures the current screen as a base64 JPEG for Claude to analyze.

import Cocoa
import ScreenCaptureKit

struct ScreenCapture {
    static func capture() async -> String? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else {
                print("[ScreenCapture] No display found")
                return nil
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = Int(display.width)
            config.height = Int(display.height)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = false

            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

            let bitmap = NSBitmapImageRep(cgImage: image)
            guard let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.4]) else {
                print("[ScreenCapture] Failed to encode JPEG")
                return nil
            }

            return jpeg.base64EncodedString()
        } catch {
            print("[ScreenCapture] Capture failed: \(error)")
            return nil
        }
    }
}
