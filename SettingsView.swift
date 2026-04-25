import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {
    var appState: AppState
    @State private var testResult: String = ""
    @State private var isTestingConnection: Bool = false

    var body: some View {
        Form {
            Section("API-Konfiguration") {
                // OpenAI API-Schlüssel
                VStack(alignment: .leading, spacing: 4) {
                    Text("OpenAI API-Schlüssel")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    SecureField("sk-...", text: Binding(
                        get: { appState.apiKey },
                        set: { appState.apiKey = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                // Modell-Auswahl
                Picker("Whisper-Modell", selection: Binding(
                    get: { appState.selectedModel },
                    set: { appState.selectedModel = $0 }
                )) {
                    ForEach(WhisperModel.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }

                // Sprache
                Picker("Sprache", selection: Binding(
                    get: { appState.language },
                    set: { appState.language = $0 }
                )) {
                    Text("Automatisch erkennen").tag("auto")
                    Text("Deutsch").tag("de")
                    Text("Englisch").tag("en")
                    Text("Französisch").tag("fr")
                    Text("Spanisch").tag("es")
                }
            }

            Section("Hotkeys") {
                HStack {
                    Text("Normale Diktation:")
                    Spacer()
                    KeyboardShortcutLabel("⌃⇧Space")
                }

                HStack {
                    Text("Formale Diktation:")
                    Spacer()
                    KeyboardShortcutLabel("⌃⇧F")
                }
            }

            Section("Verbindungstest") {
                VStack(spacing: 12) {
                    Button(action: testAPIConnection) {
                        if isTestingConnection {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Teste Verbindung...")
                            }
                        } else {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                Text("API-Verbindung testen")
                            }
                        }
                    }
                    .disabled(isTestingConnection || appState.apiKey.isEmpty)

                    if !testResult.isEmpty {
                        let isSuccess = testResult.contains("erfolgreich")
                        HStack {
                            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isSuccess ? .green : .red)
                            Text(testResult)
                                .font(.system(size: 11))
                            Spacer()
                        }
                        .padding(8)
                        .background(isSuccess ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
            }

            Section("Berechtigungen") {
                let isTrusted = AXIsProcessTrusted()
                HStack {
                    Image(systemName: isTrusted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isTrusted ? .green : .red)
                    Text("Accessibility-Berechtigung")
                    Spacer()
                    Text(isTrusted ? "Gewährt" : "Erforderlich")
                        .font(.system(size: 11))
                        .foregroundColor(isTrusted ? .green : .red)
                }

                if !isTrusted {
                    Text("Systemeinstellungen → Datenschutz & Sicherheit → Accessibility → VoiceScribe hinzufügen")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Section("Info") {
                HStack {
                    Text("Version:")
                    Spacer()
                    Text("1.0.0").foregroundColor(.secondary)
                }
                HStack {
                    Text("API:")
                    Spacer()
                    Text("OpenAI Whisper").foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 450, minHeight: 400)
        .formStyle(.grouped)
    }

    // MARK: - Verbindungstest

    private func testAPIConnection() {
        isTestingConnection = true
        testResult = ""

        Task {
            let success = await appState.testAPIConnection()
            await MainActor.run {
                isTestingConnection = false
                testResult = success
                    ? "API-Verbindung erfolgreich!"
                    : "Fehler: Verbindung fehlgeschlagen. Prüfe deinen API-Schlüssel."
            }
        }
    }
}

// MARK: - Hotkey-Label Hilfsview

struct KeyboardShortcutLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(4)
    }
}
