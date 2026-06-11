import Foundation

// MARK: - OpenAI Whisper API Response Models

struct WhisperResponse: Codable {
    let text: String
}

struct WhisperVerboseResponse: Codable {
    let task: String?
    let language: String?
    let duration: Double?
    let text: String
}

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

    func transcribe(audioFileURL: URL, language: String? = nil) async throws -> TranscriptionResult {
        guard !apiKey.isEmpty else {
            throw WhisperError.missingApiKey
        }

        let audioData = try Data(contentsOf: audioFileURL)

        #if DEBUG
        print("Audio-Datei: \(audioFileURL.lastPathComponent), Größe: \(audioData.count) bytes")
        #endif

        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: URL(string: Self.defaultEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        var body = Data()

        // MIME-Type basierend auf Dateiendung
        let ext = audioFileURL.pathExtension.lowercased()
        let mimeType: String
        switch ext {
        case "wav": mimeType = "audio/wav"
        case "m4a": mimeType = "audio/m4a"
        case "mp3": mimeType = "audio/mpeg"
        case "webm": mimeType = "audio/webm"
        default: mimeType = "audio/wav"
        }

        // Feld: file
        body.appendMultipart(boundary: boundary, name: "file",
                             filename: audioFileURL.lastPathComponent,
                             mimeType: mimeType,
                             data: audioData)

        // Feld: model
        body.appendMultipart(boundary: boundary, name: "model",
                             value: model.rawValue)

        // Feld: language
        if let language = language {
            body.appendMultipart(boundary: boundary, name: "language",
                                 value: language)
        }


        // Feld: response_format
        body.appendMultipart(boundary: boundary, name: "response_format",
                             value: "json")

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhisperError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unbekannter Fehler"
            throw WhisperError.httpError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        let decoder = JSONDecoder()
        let verboseResponse = try decoder.decode(WhisperVerboseResponse.self, from: data)

        #if DEBUG
        print("Transkription: '\(verboseResponse.text)'")
        #endif

        return TranscriptionResult(
            text: verboseResponse.text,
            detectedLanguage: verboseResponse.language,
            duration: verboseResponse.duration
        )
    }

    // MARK: - Verbindungstest

    func testConnection() async -> Bool {
        guard !apiKey.isEmpty else { return false }

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

        wav.append(Data("RIFF".utf8))
        wav.append(withUnsafeBytes(of: UInt32(pcmData.count + 36).littleEndian) { Data($0) })
        wav.append(Data("WAVE".utf8))
        wav.append(Data("fmt ".utf8))
        wav.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: channels.littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: bitDepth.littleEndian) { Data($0) })
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
            case 401: return "Ungültiger API-Schlüssel."
            case 429: return "Rate-Limit erreicht. Bitte kurz warten."
            case 413: return "Audio-Datei zu groß. Maximum: 25 MB."
            default: return "HTTP-Fehler \(statusCode): \(message)"
            }
        }
    }
}

// MARK: - Data Extension für Multipart

extension Data {
    mutating func appendMultipart(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }

    mutating func appendMultipart(boundary: String, name: String, filename: String, mimeType: String, data: Data) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
