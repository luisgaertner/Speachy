import SwiftUI
import AppKit

@main
struct VoiceScribeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    private let appState = AppState.shared
    private let history = TranscriptHistory.shared

    var body: some Scene {
        MenuBarExtra("VoiceScribe", systemImage: appState.isRecording ? "mic.fill" : "mic") {
            Text(appState.statusText)
                .font(.headline)

            Divider()

            Button(appState.isRecording && appState.currentMode == .normal
                   ? "Aufnahme stoppen"
                   : "Normale Diktation (Ctrl+Shift+Space)") {
                toggleRecording(mode: .normal)
            }

            Button(appState.isRecording && appState.currentMode == .formal
                   ? "Aufnahme stoppen"
                   : "Formale Diktation (Ctrl+Shift+F)") {
                toggleRecording(mode: .formal)
            }

            Divider()

            // MARK: - Verlauf

            if history.entries.isEmpty {
                Text("Kein Verlauf")
                    .foregroundStyle(.secondary)
            } else {
                Menu("Verlauf (\(history.entries.count))") {
                    ForEach(history.entries.prefix(15)) { entry in
                        Button {
                            history.copyToClipboard(entry)
                            appState.statusText = "Kopiert!"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                if appState.statusText == "Kopiert!" {
                                    appState.statusText = "Bereit"
                                }
                            }
                        } label: {
                            let icon = entry.mode == "formal" ? "📝" : "🎤"
                            Text("\(icon) \(entry.preview)  —  \(entry.formattedDate)")
                        }
                    }

                    if history.entries.count > 15 {
                        Divider()
                        Text("... und \(history.entries.count - 15) weitere")
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    Button("Verlauf löschen", role: .destructive) {
                        history.clearAll()
                    }
                }
            }

            Divider()

            Button("Einstellungen...") {
                DispatchQueue.main.async {
                    SettingsWindowController.shared.showWindow()
                }
            }

            Divider()

            Button("Beenden") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func toggleRecording(mode: RecordingMode) {
        if appState.isRecording {
            Task {
                await appState.stopRecording()
            }
        } else {
            appState.startRecording(mode: mode)
        }
    }
}

// MARK: - Settings Window Controller

class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var windowController: NSWindowController?

    func showWindow() {
        // Falls Fenster schon offen, nach vorne bringen
        if let wc = windowController, let window = wc.window, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Neues Fenster erstellen
        let settingsView = SettingsView(appState: AppState.shared)
        let hostingController = NSHostingController(rootView: settingsView)
        hostingController.preferredContentSize = NSSize(width: 500, height: 480)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "VoiceScribe — Einstellungen"
        window.setContentSize(NSSize(width: 500, height: 480))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.level = .floating  // Über anderen Fenstern

        let wc = NSWindowController(window: window)
        self.windowController = wc

        // App temporär aktivierbar machen
        NSApp.setActivationPolicy(.accessory)
        wc.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hotkeyManager: HotkeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }

        hotkeyManager = HotkeyManager()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
