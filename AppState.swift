import AppKit
import Foundation
import Observation

// MARK: - Recording Mode

enum RecordingMode {
    case normal  // Direkte Transkription
    case formal  // Transkription + formelles Umschreiben
}

// MARK: - AppState (Singleton)

@Observable
final class AppState {
    static let shared = AppState()

    // Aufnahme-Status
    var isRecording: Bool = false
    var currentMode: RecordingMode = .normal
    var statusText: String = "Bereit"

    // API-Konfiguration (in UserDefaults gespeichert)
    @ObservationIgnored
    private var _apiKey: String {
        get { UserDefaults.standard.string(forKey: "openaiApiKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "openaiApiKey") }
    }

    @ObservationIgnored
    private var _modelRawValue: String {
        get { UserDefaults.standard.string(forKey: "whisperModel") ?? WhisperModel.gpt4oTranscribe.rawValue }
        set { UserDefaults.standard.set(newValue, forKey: "whisperModel") }
    }

    @ObservationIgnored
    private var _language: String {
        get { UserDefaults.standard.string(forKey: "language") ?? "auto" }
        set { UserDefaults.standard.set(newValue, forKey: "language") }
    }

    // Öffentliche Properties mit Observation-Trigger
    var apiKey: String {
        get { _apiKey }
        set {
            _apiKey = newValue
            rebuildService()
        }
    }

    var selectedModel: WhisperModel {
        get { WhisperModel(rawValue: _modelRawValue) ?? .gpt4oTranscribe }
        set {
            _modelRawValue = newValue.rawValue
            rebuildService()
        }
    }

    /// "auto" für automatische Erkennung, oder ISO-639-1 Code wie "de", "en"
    var language: String {
        get { _language }
        set { _language = newValue }
    }

    // Services
    @ObservationIgnored
    private let audioRecorder = AudioRecorder()

    @ObservationIgnored
    private var whisperService: WhisperService?

    @ObservationIgnored
    private let textInserter = TextInserter()

    @ObservationIgnored
    private let rewriteService = RewriteService()

    // MARK: - Init

    init() {
        rebuildService()
    }

    private func rebuildService() {
        whisperService = WhisperService(
            apiKey: _apiKey,
            model: WhisperModel(rawValue: _modelRawValue) ?? .gpt4oTranscribe
        )
    }

    // MARK: - Aufnahme starten

    func startRecording(mode: RecordingMode) {
        guard !isRecording else { return }

        currentMode = mode
        isRecording = true
        statusText = mode == .normal ? "Aufnahme läuft..." : "Aufnahme (formal)..."

        // Akustisches Feedback
        NSSound.beep()

        audioRecorder.startRecording()
    }

    // MARK: - Aufnahme stoppen + Transkribieren

    func stopRecording() async {
        guard isRecording else { return }

        isRecording = false
        statusText = "Transkribiere..."

        // Akustisches Feedback
        NSSound.beep()

        // Audio-Datei erhalten
        guard let audioURL = audioRecorder.stopRecording() else {
            statusText = "Fehler: Aufnahme fehlgeschlagen"
            resetStatusAfterDelay()
            return
        }

        // Transkription starten
        await transcribeAndInsert(audioURL: audioURL)
    }

    // MARK: - Transkription + Einfügen

    private func transcribeAndInsert(audioURL: URL) async {
        guard let service = whisperService else {
            statusText = "Fehler: API nicht konfiguriert"
            resetStatusAfterDelay()
            return
        }

        do {
            // Sprache bestimmen (nil = automatisch)
            let lang: String? = (language == "auto") ? nil : language

            // Transkribiere über OpenAI Whisper API
            let result = try await service.transcribe(
                audioFileURL: audioURL,
                language: lang
            )

            var finalText = result.text

            // Im formalen Modus: Text umschreiben
            if currentMode == .formal {
                statusText = "Formalisiere..."
                finalText = await rewriteService.rewriteFormal(text: finalText)
            }

            // Text an Cursor-Position einfügen
            await MainActor.run {
                textInserter.insertText(finalText)
                statusText = "Bereit"
            }

            if let detectedLang = result.detectedLanguage {
                #if DEBUG
                print("Erkannte Sprache: \(detectedLang), Dauer: \(result.duration ?? 0)s")
                #endif
            }

        } catch {
            await MainActor.run {
                statusText = "Fehler: \(error.localizedDescription)"
                resetStatusAfterDelay()
            }
        }

        // Temporäre Audio-Datei aufräumen
        try? FileManager.default.removeItem(at: audioURL)
    }

    // MARK: - API-Verbindungstest

    func testAPIConnection() async -> Bool {
        guard let service = whisperService else { return false }
        return await service.testConnection()
    }

    // MARK: - Hilfs-Funktionen

    private func resetStatusAfterDelay() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if self?.statusText.hasPrefix("Fehler") == true {
                self?.statusText = "Bereit"
            }
        }
    }
}
