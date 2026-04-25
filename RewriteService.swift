import Foundation

class RewriteService {

    /// Schreibt den transkribierten Text formal um via OpenAI GPT-4o-mini
    func rewriteFormal(text: String) async -> String {
        let apiKey = UserDefaults.standard.string(forKey: "openaiApiKey") ?? ""

        guard !apiKey.isEmpty else {
            #if DEBUG
            print("RewriteService: Kein API-Key, gebe Originaltext zurueck")
            #endif
            return text
        }

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "max_tokens": 1024,
            "temperature": 0.7,
            "messages": [
                [
                    "role": "system",
                    "content": "Du bist ein professioneller Schreibassistent. Schreibe den folgenden Text in formaler, professioneller Sprache um. Behalte die Bedeutung bei, aber mache den Text hoeflicher, professioneller und geschaeftlich angemessen. Antworte NUR mit dem umgeschriebenen Text, ohne Erklaerungen oder Anfuehrungszeichen."
                ],
                [
                    "role": "user",
                    "content": text
                ]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                #if DEBUG
                let errorBody = String(data: data, encoding: .utf8) ?? "Unbekannt"
                print("RewriteService Fehler: \(errorBody)")
                #endif
                return text
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                #if DEBUG
                print("RewriteService: Antwort konnte nicht geparsed werden")
                #endif
                return text
            }

            let result = content.trimmingCharacters(in: .whitespacesAndNewlines)
            #if DEBUG
            print("RewriteService: '\(text)' -> '\(result)'")
            #endif
            return result

        } catch {
            #if DEBUG
            print("RewriteService Fehler: \(error)")
            #endif
            return text
        }
    }
}
