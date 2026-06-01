//
//  VoiceEngine.swift
//  heymax
//
//  Always-on voice listener. Detects "hey max" wake word,
//  then captures the full command and sends to Claude.

import Foundation
import Speech
import AVFoundation

class VoiceEngine: NSObject, ObservableObject {
    static let shared = VoiceEngine()

    @Published var isListening = false
    @Published var isProcessing = false
    @Published var lastTranscript = ""
    @Published var wakeWordDetected = false

    private let audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    private let wakePhrase = "hey max"
    private var silenceTimer: Timer?
    private var commandBuffer = ""

    override init() {
        super.init()
    }

    // MARK: - Permissions

    func requestPermissions(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    AVCaptureDevice.requestAccess(for: .audio) { granted in
                        DispatchQueue.main.async { completion(granted) }
                    }
                default:
                    completion(false)
                }
            }
        }
    }

    // MARK: - Start Listening

    func startListening() {
        guard !isListening else { return }
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            print("[VoiceEngine] Speech recognizer not available")
            return
        }

        do {
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let request = recognitionRequest else { return }
            request.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                request.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            isListening = true
            print("[VoiceEngine] Listening for 'hey max'...")

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self = self else { return }

                if let result = result {
                    let text = result.bestTranscription.formattedString.lowercased()

                    if !self.wakeWordDetected {
                        // Listening for wake word
                        if text.contains(self.wakePhrase) {
                            DispatchQueue.main.async {
                                self.wakeWordDetected = true
                                self.commandBuffer = ""
                                print("[VoiceEngine] Wake word detected!")
                                OverlayWindow.shared?.show(state: .listening)
                            }
                            // Reset silence timer
                            self.resetSilenceTimer()
                        }
                    } else {
                        // Capturing command after wake word
                        let afterWake = text.components(separatedBy: self.wakePhrase).last?.trimmingCharacters(in: .whitespaces) ?? ""
                        if !afterWake.isEmpty {
                            DispatchQueue.main.async {
                                self.commandBuffer = afterWake
                                self.lastTranscript = afterWake
                            }
                            self.resetSilenceTimer()
                        }
                    }
                }

                if error != nil || (result?.isFinal ?? false) {
                    self.stopAndRestart()
                }
            }

        } catch {
            print("[VoiceEngine] Audio engine error: \(error)")
        }
    }

    // MARK: - Silence Detection

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            guard let self = self, self.wakeWordDetected else { return }
            self.processCommand()
        }
    }

    private func processCommand() {
        guard !commandBuffer.isEmpty else {
            wakeWordDetected = false
            return
        }

        let command = commandBuffer
        DispatchQueue.main.async {
            self.isProcessing = true
            self.wakeWordDetected = false
            OverlayWindow.shared?.show(state: .thinking)
        }

        print("[VoiceEngine] Processing command: \(command)")

        // Capture screen + send to Claude
        Task {
            let screenshot = await ScreenCapture.capture()
            let response = await ClaudeAPI.shared.process(command: command, screenshot: screenshot)

            await MainActor.run {
                self.isProcessing = false

                if let action = response.action {
                    ActionRunner.run(action)
                }

                OverlayWindow.shared?.show(state: .response(response.text))

                // Auto-hide after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    OverlayWindow.shared?.hide()
                }
            }
        }

        stopAndRestart()
    }

    // MARK: - Stop / Restart

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isListening = false
        wakeWordDetected = false
    }

    private func stopAndRestart() {
        stopListening()
        // Restart after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.startListening()
        }
    }
}
