import Foundation
import Combine

// Transcription update structure for streaming
struct TranscriptionUpdate {
    let text: String
    let progress: Double
    let segments: [TranscriptionSegmentData]
    let isComplete: Bool
}

@MainActor
class TranscriptionService {
    private let modelManager = ModelManager.shared
    private let languageManager = LanguageManager.shared
    private var whisperKitService: WhisperKitService?
    
    func transcribe(fileURL: URL) -> AsyncThrowingStream<TranscriptionUpdate, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // Check if we have a downloaded model
                    guard let selectedModel = UserDefaults.standard.string(forKey: "selectedTranscriptionModel"),
                          !selectedModel.isEmpty else {
                        throw TranscriptionError.noModelSelected
                    }
                    
                    try await transcribeWithWhisperKit(
                        fileURL: fileURL,
                        modelId: selectedModel,
                        continuation: continuation
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func transcribeWithWhisperKit(
        fileURL: URL,
        modelId: String,
        continuation: AsyncThrowingStream<TranscriptionUpdate, Error>.Continuation
    ) async throws {
        // Initialize WhisperKit service if needed
        if whisperKitService == nil {
            whisperKitService = WhisperKitService()
        }
        
        // Use WhisperKit for standard models
        guard let service = whisperKitService else {
            throw TranscriptionError.modelNotFound
        }
        
        // If the file is a video container or non-native audio format,
        // extract the audio track to a temporary .m4a first.
        let preprocessor = AudioPreprocessor.shared
        let needsConversion = preprocessor.needsConversionForWhisperKit(url: fileURL)
        var audioURL = fileURL
        
        if needsConversion {
            continuation.yield(TranscriptionUpdate(
                text: NSLocalizedString("converting_audio_format", comment: ""),
                progress: 0.02,
                segments: [],
                isComplete: false
            ))
            audioURL = try await preprocessor.extractAudioForWhisperKit(url: fileURL)
        }
        
        defer {
            // Clean up the temporary file if we created one
            if needsConversion {
                try? FileManager.default.removeItem(at: audioURL)
            }
        }
        
        // Get the selected language
        let selectedLanguage = languageManager.selectedLanguage.code
        
        // Stream transcription updates with model and language
        for try await update in service.transcribe(fileURL: audioURL, modelId: modelId, language: selectedLanguage) {
            continuation.yield(update)
            
            if update.isComplete {
                continuation.finish()
                return
            }
        }
        
        // If the loop exits without isComplete, still finish the stream
        continuation.finish()
    }
    
    func cancelTranscription() {
        // WhisperKit handles cancellation internally
    }
}

enum TranscriptionError: LocalizedError {
    case noModelSelected
    case modelNotFound
    case unsupportedModel
    
    var errorDescription: String? {
        switch self {
        case .noModelSelected:
            return "No transcription model selected"
        case .modelNotFound:
            return "Selected model not found. Please download it first."
        case .unsupportedModel:
            return "Unsupported model type"
        }
    }
}