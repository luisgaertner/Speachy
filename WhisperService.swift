import Foundation

// MARK: - OpenAI Whisper API Response Models

/// Standard-Antwort der OpenAI Transcription API (response_format: "json")
struct WhisperResponse: Codable {
    let text: String
}

/// Erweiterte Antwort mit Details (response_format: "verbose_json")
struct WhisperVerboseResponse: Codable {
    let task: String?
    let language: String?
    let duration: Double?
    let text: String
}

/// Internes Ergebnis für die App
struct TranscriptionResult {
    let text: String
    let detectedLanguage: String?
    let duration: Double?
}

// MARK: - Verfügbare Whisper-Modelle

enum WhisperModel: String, CaseIterable, Identifiable {
    case gpt4oTranscribe = "gpt-4o-transcribe"
    case gpt4oMiniTranscribe = "gpt-4o-mini-transcribe"
    case whisper1 = "whisper-1"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gpt4oTranscribe: return "GPT-4o Transcribe (beste Qualität)"
        case .gpt4oMiniTranscribe: return "GPT-4o Mini Transcribe (schneller)"
        case .whisper1: return "Whisper-1 (klassisch)"
        }
    }
}

// MARK: - WhisperService

class WhisperService {
    private let apiKey: String
    private let model: WhisperModel
    private let session = URLSession.shared

    static let defaultEndpoint = "https://api.openai.com/v1/audio/transcriptions"

    init(apiKey: String, model: WhisperModel = .gpt4oTranscribe) {
        self.apiKey = apiKey
        self.model = model
    }

    // MARK: - Transkription

    /// Transkribiert eine Audio-Datei über die OpenAI Whisper API
    /// - Parameters:
    ///   - audioFileURL: Pfad zur WAV-Datei
    ///   - language: Optionaler ISO-639-1 Sprachcode (z.B. "de", "en"). Nil = automatische Erkennung
    /// - Returns: TranscriptionResult mit dem transkribierten Text
    func transcribe(audioFileURL: URL, language: String? = nil) async throws -> TranscriptionResult {
        guard !apiKey.isEmpty else {
            throw WhisperError.missingApiKey
        }

        // Lese Audio-Datei
        let audioData = try Data(contentsOf: audioFileURL)

        // Erstelle Multipart-Request
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: URL(string: Self.defaultEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60 // 60 Sekunden Timeout

        // Baue Multipart-Body
        var body = Data()

        // Feld: file (die Audio-Datei)
        body.appendMultipart(boundary: boundary, name: "file",
                             filename: audioFileURL.lastPathComponent,
                             mimeType: "audio/m4a",
                             data: audioData)

        // Feld: model
        body.appendMultipart(boundary: boundary, name: "model",
                             value: model.rawValue)

        // Feld: language (optional — verbessert Genauigkeit wenn angegeben)
        if let language = language {
            body.appendMultipart(boundary: boundary, name: "language",
                                 value: language)
        }

        // Feld: response_format — verbose_json für Spracherkennung
        body.appendMultipart(boundary: boundary, name: "response_format",
                             value: "json")

        // Abschluss-Boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // Sende Request
        let (data, response) = try await session.data(for: request)

        // Prüfe HTTP-Status
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhisperError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unbekannter Fehler"
            throw WhisperError.httpError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        // Dekodiere Antwort
        let decoder = JSONDecoder()
        let verboseResponse = try decoder.decode(WhisperVerboseResponse.self, from: data)

        return TranscriptionResult(
            text: verboseResponse.text,
            detectedLanguage: verboseResponse.language,
            duration: verboseResponse.duration
        )
    }

    // MARK: - Verbindungstest

    /// Testet die API-Verbindung mit einer kurzen stillen WAV-Datei
    func testConnection() async -> Bool {
        guard !apiKey.isEmpty else { return false }

        // Erstelle minimale Test-WAV (0.5 Sekunden Stille)
        let testURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper_test_\(UUID().uuidString).wav")

        do {
            let testData = createSilentWAV(durationSeconds: 0.5)
            try testData.write(to: testURL)
            _ = try await transcribe(audioFileURL: testURL)
            try? FileManager.default.removeItem(at: testURL)
            return true
        } catch {
            #if DEBUG
            print("API-Verbindungstest fehlgeschlagen: \(error)")
            #endif
            try? FileManager.default.removeItem(at: testURL)
            return false
        }
    }

    // MARK: - Hilfs-Funktionen

    /// Erstellt eine stille WAV-Datei für den Verbindungstest
    private func createSilentWAV(durationSeconds: Double) -> Data {
        let sampleRate: Int = 16000
        let numSamples = Int(Double(sampleRate) * durationSeconds)
        let audioSamples = [Int16](repeating: 0, count: numSamples)
        let pcmData = audioSamples.withUnsafeBytes { Data($0) }

        var wav = Data()
        let channels: UInt16 = 1
        let bitDepth: UInt16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(channels) * UInt32(bitDepth / 8)
        let blockAlign = channels * (bitDepth / 8)

        // RIFF Header
        wav.append(Data("RIFF".utf8))
        wav.append(withUnsafeBytes(of: UInt32(pcmData.count + 36).littleEndian) { Data($0) })
        wav.append(Data("WAVE".utf8))

        // fmt Chunk
        wav.append(Data("fmt ".utf8))
        wav.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // PCM
        wav.append(withUnsafeBytes(of: channels.littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: bitDepth.littleEndian) { Data($0) })

        // data Chunk
        wav.append(Data("data".utf8))
        wav.append(withUnsafeBytes(of: UInt32(pcmData.count).littleEndian) { Data($0) })
        wav.append(pcmData)

        return wav
    }
}

// MARK: - Fehler-Typen

enum WhisperError: LocalizedError {
    case missingApiKey
    case invalidResponse
    case httpError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "OpenAI API-Schlüssel nicht konfiguriert. Bitte in den Einstellungen eintragen."
        case .invalidResponse:
            return "Ungültige Antwort vom Server."
        case .httpError(let statusCode, let message):
            switch statusCode {
            case 401:
                return "Ungültiger API-Schlüssel. Bitte prüfen Sie Ihren OpenAI API-Key."
            case 429:
                return "Rate-Limit erreicht. Bitte kurz warten."
            case 413:
                return "Audio-Datei zu groß. Maximum: 25 MB."
            default:
                return "HTTP-Fehler \(statusCode): \(message)"
            }
        }
    }
}

// MARK: - Data Extension für Multipart

extension Data {
    /// Fügt ein Text-Feld zum Multipart-Body hinzu
    mutating func appendMultipart(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    /// Fügt eine Datei zum Multipart-Body hinzu
    mutating func appendMultipart(boundary: String, name: String, filename: String, mimeType: String, data: Data) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
