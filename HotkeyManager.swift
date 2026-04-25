import AppKit
import Foundation

// MARK: - HotkeyManager

class HotkeyManager {
    private var eventTap: CFMachPort?

    init() {
        // Prüfe Accessibility-Berechtigungen
        if !AXIsProcessTrusted() {
            #if DEBUG
            print("Warnung: Accessibility-Berechtigungen werden benötigt für globale Hotkeys")
            #endif
        }

        setupGlobalHotkeys()
    }

    deinit {
        if let eventTap = eventTap {
            CFMachPortInvalidate(eventTap)
        }
    }

    // MARK: - Setup

    private func setupGlobalHotkeys() {
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { proxy, type, event, context in
                let this = Unmanaged<HotkeyManager>.fromOpaque(context!).takeUnretainedValue()
                this.handleKeyEvent(event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            #if DEBUG
            print("Fehler: Global Event Tap konnte nicht erstellt werden. Accessibility-Berechtigung nötig.")
            #endif
            return
        }

        self.eventTap = eventTap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)

        #if DEBUG
        print("Globale Hotkeys registriert (Ctrl+Shift+Space = Normal, Ctrl+Shift+F = Formal)")
        #endif
    }

    // MARK: - Event Handling

    private func handleKeyEvent(_ event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        let isCtrlPressed = flags.contains(.maskControl)
        let isShiftPressed = flags.contains(.maskShift)
        let isCmdPressed = flags.contains(.maskCommand)

        // Nur Ctrl+Shift Kombinationen (ohne Cmd)
        guard isCtrlPressed, isShiftPressed, !isCmdPressed else { return }

        // Normale Diktation: Ctrl+Shift+Space (Keycode 49)
        if keyCode == 49 {
            DispatchQueue.main.async {
                self.toggleRecording(mode: .normal)
            }
        }

        // Formale Diktation: Ctrl+Shift+F (Keycode 3)
        if keyCode == 3 {
            DispatchQueue.main.async {
                self.toggleRecording(mode: .formal)
            }
        }
    }

    // MARK: - Recording Toggle

    private func toggleRecording(mode: RecordingMode) {
        let appState = AppState.shared

        if appState.isRecording {
            Task {
                await appState.stopRecording()
            }
        } else {
            appState.startRecording(mode: mode)
        }
    }
}
