import AVFoundation
import Foundation
import CoreAudio

class AudioRecorder: NSObject, AVCaptureFileOutputRecordingDelegate {
    private var captureSession: AVCaptureSession?
    private var audioOutput: AVCaptureAudioFileOutput?
    private var currentURL: URL?
    private var isRecording = false

    override init() {
        super.init()
        checkPermissions()
    }

    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                #if DEBUG
                print("Mikrofon-Berechtigung erteilt: \(granted)")
                #endif
            }
        case .denied, .restricted:
            #if DEBUG
            print("FEHLER: Mikrofon-Berechtigung nicht erteilt")
            #endif
        @unknown default:
            break
        }
    }

    func startRecording() {
        guard !isRecording else { return }

        let session = AVCaptureSession()

        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            #if DEBUG
            print("FEHLER: Kein Audiogeraet verfuegbar")
            #endif
            return
        }

        #if DEBUG
        print("Nehme auf mit: \(audioDevice.localizedName)")
        #endif

        do {
            let audioInput = try AVCaptureDeviceInput(device: audioDevice)

            if session.canAddInput(audioInput) {
                session.addInput(audioInput)
            } else {
                return
            }

            let output = AVCaptureAudioFileOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
            } else {
                return
            }

            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "recording_\(UUID().uuidString).m4a"
            let url = tempDir.appendingPathComponent(fileName)
            currentURL = url

            session.startRunning()
            self.captureSession = session
            self.audioOutput = output

            output.startRecording(
                to: url,
                outputFileType: .m4a,
                recordingDelegate: self
            )

            isRecording = true
            #if DEBUG
            print("Aufnahme gestartet")
            #endif

        } catch {
            #if DEBUG
            print("Aufnahme-Fehler: \(error)")
            #endif
        }
    }

    func stopRecording() -> URL? {
        guard isRecording else { return nil }

        isRecording = false
        audioOutput?.stopRecording()
        captureSession?.stopRunning()
        captureSession = nil
        audioOutput = nil

        #if DEBUG
        if let url = currentURL {
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
            print("Aufnahme gestoppt, Datei: \(fileSize) bytes")
        }
        #endif

        return currentURL
    }

    // MARK: - AVCaptureFileOutputRecordingDelegate

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        #if DEBUG
        if let error = error {
            print("Aufnahme-Delegate Fehler: \(error)")
        }
        #endif
    }
}
