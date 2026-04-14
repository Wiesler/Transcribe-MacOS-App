import SwiftUI

class AppState: ObservableObject {
    @Published var currentTranscriptionURL: URL?
    @Published var showTranscriptionView = false
    @Published var showRecordingView = false
    @Published var showSystemAudioView = false
    @Published var showSammanfattaView = false
    @Published var sammanfattaText: String = ""

    func openFileForTranscription(_ url: URL) {
        currentTranscriptionURL = url
        showTranscriptionView = true
    }

    func openSammanfatta(text: String) {
        sammanfattaText = text
        showSammanfattaView = true
    }
}