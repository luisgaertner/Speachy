import AppKit

// MARK: - Transcript Entry

struct TranscriptEntry: Codable, Identifiable {
    let id: UUID
    let text: String
    let date: Date
    let mode: String  // "normal" oder "formal"

    init(text: String, mode: RecordingMode) {
        self.id = UUID()
        self.text = text
        self.date = Date()
        self.mode = mode == .formal ? "formal" : "normal"
    }

    /// Vorschau-Text für das Menü (max. 50 Zeichen)
    var preview: String {
        let clean = text.replacingOccurrences(of: "\n", with: " ")
        if clean.count > 50 {
            return String(clean.prefix(47)) + "..."
        }
        return clean
    }

    /// Formatiertes Datum
    var formattedDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
            return "Heute, \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "HH:mm"
            return "Gestern, \(formatter.string(from: date))"
        } else {
            formatter.dateFormat = "dd.MM.yy, HH:mm"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Transcript History Manager

@Observable
final class TranscriptHistory {
    static let shared = TranscriptHistory()

    private let maxEntries = 50
    private let storageKey = "transcriptHistory"

    private(set) var entries: [TranscriptEntry] = []

    init() {
        loadEntries()
    }

    /// Neuen Eintrag hinzufügen
    func add(text: String, mode: RecordingMode) {
        let entry = TranscriptEntry(text: text, mode: mode)
        entries.insert(entry, at: 0)

        // Auf maxEntries begrenzen
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        saveEntries()
    }

    /// Eintrag in Zwischenablage kopieren
    func copyToClipboard(_ entry: TranscriptEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.text, forType: .string)
    }

    /// Einzelnen Eintrag löschen
    func delete(_ entry: TranscriptEntry) {
        entries.removeAll { $0.id == entry.id }
        saveEntries()
    }

    /// Gesamten Verlauf löschen
    func clearAll() {
        entries.removeAll()
        saveEntries()
    }

    // MARK: - Persistenz

    private func saveEntries() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let loaded = try? JSONDecoder().decode([TranscriptEntry].self, from: data) else {
            return
        }
        entries = loaded
    }
}
