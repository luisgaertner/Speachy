import AppKit
import Foundation

// MARK: - TextInserter

class TextInserter {
    private let pasteboard = NSPasteboard.general

    // MARK: - Text an Cursor-Position einfügen

    func insertText(_ text: String) {
        // Speichere aktuellen Pasteboard-Inhalt
        let previousContent = pasteboard.string(forType: .string)

        // Setze transkribierten Text in Pasteboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Simuliere Cmd+V (Einfügen)
        let source = CGEventSource(stateID: .hidSystemState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true) // 9 = V-Taste
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)

        // Kurze Verzögerung, damit die App den Paste verarbeiten kann
        usleep(150_000) // 150ms

        // Stelle vorherigen Pasteboard-Inhalt wieder her
        pasteboard.clearContents()
        if let previousContent = previousContent {
            pasteboard.setString(previousContent, forType: .string)
        }
    }
}
