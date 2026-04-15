//
//  TranscribeTests.swift
//  TranscribeTests
//

import Testing
import Foundation
@testable import Transcribe

// MARK: - AudioRingBuffer Tests

struct AudioRingBufferTests {

    // MARK: Helpers

    /// Write `frames` frames of `value` into the buffer (mono or stereo depending on channelCount).
    private func write(into rb: AudioRingBuffer, value: Float, frames: Int, channels: Int) {
        var data = [Float](repeating: value, count: frames * channels)
        data.withUnsafeBufferPointer { ptr in
            rb.write(from: ptr.baseAddress!, frameCount: frames, channelCount: channels)
        }
    }

    /// Read `frames` frames from the buffer; returns the output array and the actual frame count read.
    private func read(from rb: AudioRingBuffer, frames: Int, channels: Int) -> (output: [Float], read: Int) {
        var output = [Float](repeating: 0, count: frames * channels)
        let count = output.withUnsafeMutableBufferPointer { ptr in
            rb.read(into: ptr.baseAddress!, frameCount: frames, channelCount: channels)
        }
        return (output, count)
    }

    // MARK: Tests

    @Test func writeAndReadRoundTrip() {
        let rb = AudioRingBuffer(capacity: 100, channelCount: 2)
        // Non-interleaved: L[0..99] = 1.0, R[0..99] = 2.0
        var input = [Float](repeating: 1.0, count: 100) + [Float](repeating: 2.0, count: 100)
        input.withUnsafeBufferPointer { ptr in
            rb.write(from: ptr.baseAddress!, frameCount: 100, channelCount: 2)
        }
        #expect(rb.availableFrames == 100)

        var output = [Float](repeating: 0, count: 200)
        let framesRead = output.withUnsafeMutableBufferPointer { ptr in
            rb.read(into: ptr.baseAddress!, frameCount: 100, channelCount: 2)
        }
        #expect(framesRead == 100)
        #expect(rb.availableFrames == 0)
        // L channel stored in output[0..99], R channel in output[100..199]
        #expect(output[0] == 1.0)
        #expect(output[99] == 1.0)
        #expect(output[100] == 2.0)
        #expect(output[199] == 2.0)
    }

    @Test func readFromEmptyBufferReturnsZero() {
        let rb = AudioRingBuffer(capacity: 64, channelCount: 1)
        let (_, count) = read(from: rb, frames: 64, channels: 1)
        #expect(count == 0)
        #expect(rb.availableFrames == 0)
    }

    @Test func availableFramesTracking() {
        let rb = AudioRingBuffer(capacity: 200, channelCount: 1)
        write(into: rb, value: 0.5, frames: 100, channels: 1)
        #expect(rb.availableFrames == 100)

        let (_, _) = read(from: rb, frames: 40, channels: 1)
        #expect(rb.availableFrames == 60)
    }

    @Test func writeExceedingCapacityIsLossy() {
        let rb = AudioRingBuffer(capacity: 10, channelCount: 1)
        write(into: rb, value: 0.5, frames: 20, channels: 1)
        // Buffer clamps at capacity
        #expect(rb.availableFrames == 10)
    }

    @Test func wrapAroundOnWrite() {
        let rb = AudioRingBuffer(capacity: 10, channelCount: 1)

        // Advance write and read positions to 8 by writing then draining 8 frames
        write(into: rb, value: 0, frames: 8, channels: 1)
        let (_, _) = read(from: rb, frames: 8, channels: 1)
        // State: writePos=8, readPos=8, available=0

        // Write 5 frames that wrap around end-of-buffer (positions 8, 9, 0, 1, 2)
        var data = (0..<5).map { Float($0 + 100) }  // [100, 101, 102, 103, 104]
        data.withUnsafeBufferPointer { ptr in
            rb.write(from: ptr.baseAddress!, frameCount: 5, channelCount: 1)
        }
        #expect(rb.availableFrames == 5)

        var output = [Float](repeating: 0, count: 5)
        let framesRead = output.withUnsafeMutableBufferPointer { ptr in
            rb.read(into: ptr.baseAddress!, frameCount: 5, channelCount: 1)
        }
        #expect(framesRead == 5)
        #expect(output[0] == 100.0)
        #expect(output[4] == 104.0)
    }

    @Test func resetClearsBuffer() {
        let rb = AudioRingBuffer(capacity: 50, channelCount: 1)
        write(into: rb, value: 1.0, frames: 50, channels: 1)
        #expect(rb.availableFrames == 50)

        rb.reset()
        #expect(rb.availableFrames == 0)

        let (_, count) = read(from: rb, frames: 50, channels: 1)
        #expect(count == 0)
    }

    @Test func partialReadReturnsActualFrameCount() {
        let rb = AudioRingBuffer(capacity: 200, channelCount: 1)
        write(into: rb, value: 1.0, frames: 50, channels: 1)

        // Request more frames than available
        let (_, count) = read(from: rb, frames: 200, channels: 1)
        #expect(count == 50)
        #expect(rb.availableFrames == 0)
    }

    @Test func mismatchedChannelCountIsIgnored() {
        let rb = AudioRingBuffer(capacity: 100, channelCount: 2)
        // Write with wrong channel count (1 instead of 2) — buffer should stay empty
        write(into: rb, value: 1.0, frames: 100, channels: 1)
        #expect(rb.availableFrames == 0)
    }

    @Test func stereoChannelDataStoredCorrectly() {
        // Verify non-interleaved channel layout is preserved end-to-end
        let rb = AudioRingBuffer(capacity: 4, channelCount: 2)
        // L: [10, 20, 30, 40], R: [50, 60, 70, 80]
        var input: [Float] = [10, 20, 30, 40, 50, 60, 70, 80]
        input.withUnsafeBufferPointer { ptr in
            rb.write(from: ptr.baseAddress!, frameCount: 4, channelCount: 2)
        }

        var output = [Float](repeating: 0, count: 8)
        output.withUnsafeMutableBufferPointer { ptr in
            rb.read(into: ptr.baseAddress!, frameCount: 4, channelCount: 2)
        }

        // L channel in output[0..3], R channel in output[4..7]
        #expect(output[0] == 10); #expect(output[3] == 40)
        #expect(output[4] == 50); #expect(output[7] == 80)
    }
}

// MARK: - AudioPreprocessor Tests

struct AudioPreprocessorTests {

    private func url(ext: String) -> URL {
        URL(fileURLWithPath: "/tmp/testfile.\(ext)")
    }

    // MARK: Format Detection

    @Test func nativeAudioFormatsNeedNoConversion() {
        let preprocessor = AudioPreprocessor()
        for ext in ["wav", "mp3", "m4a", "flac", "aac", "aif", "aiff", "caf"] {
            #expect(!preprocessor.needsConversionForWhisperKit(url: url(ext: ext)))
        }
    }

    @Test func videoFormatsNeedConversion() {
        let preprocessor = AudioPreprocessor()
        for ext in ["mp4", "mov", "mkv", "avi", "webm"] {
            #expect(preprocessor.needsConversionForWhisperKit(url: url(ext: ext)))
        }
    }

    @Test func unknownExtensionNeedsConversion() {
        let preprocessor = AudioPreprocessor()
        #expect(preprocessor.needsConversionForWhisperKit(url: url(ext: "xyz")))
        #expect(preprocessor.needsConversionForWhisperKit(url: URL(fileURLWithPath: "/tmp/noextension")))
    }

    // MARK: Merge Helpers

    private func seg(id: Int, start: Double, end: Double, text: String) -> TranscriptionSegment {
        TranscriptionSegment(id: id, start: start, end: end, text: text, confidence: nil, speaker: nil)
    }

    private func result(text: String, segments: [TranscriptionSegment] = [],
                        language: String = "sv", model: String = "test") -> TranscriptionResult {
        TranscriptionResult(text: text, segments: segments, language: language,
                            duration: 60, timestamp: Date(), modelUsed: model)
    }

    private func chunk(start: Double, end: Double, index: Int = 0) -> AudioPreprocessor.AudioChunk {
        AudioPreprocessor.AudioChunk(
            url: URL(fileURLWithPath: "/tmp/chunk\(index).m4a"),
            startTime: start, endTime: end, index: index)
    }

    // MARK: Merge Tests

    @Test func mergeEmptyInputReturnsEmptyResult() {
        let merged = AudioPreprocessor().mergeChunkedTranscriptions([])
        #expect(merged.text == "")
        #expect(merged.segments.isEmpty)
        #expect(merged.language == "unknown")
    }

    @Test func mergeSingleChunkPassesThrough() {
        let s = seg(id: 0, start: 1.0, end: 2.0, text: "hello world")
        let r = result(text: "hello world", segments: [s])
        let c = chunk(start: 0, end: 60)

        let merged = AudioPreprocessor().mergeChunkedTranscriptions([(chunk: c, result: r)])
        #expect(merged.text == "hello world")
        #expect(merged.segments.count == 1)
        #expect(merged.language == "sv")
        #expect(merged.modelUsed == "test")
    }

    @Test func mergeAdjustsSegmentTimestampsByChunkStartTime() {
        // Second chunk starts at 60 s; its segment at 35 s should land at 95 s in the merged result
        let r1 = result(text: "first", segments: [seg(id: 0, start: 5, end: 10, text: "first")])
        let c1 = chunk(start: 0, end: 60, index: 0)

        let r2 = result(text: "second", segments: [seg(id: 0, start: 35, end: 40, text: "second")])
        let c2 = chunk(start: 60, end: 120, index: 1)

        let merged = AudioPreprocessor().mergeChunkedTranscriptions([
            (chunk: c1, result: r1), (chunk: c2, result: r2)
        ])

        let secondSeg = merged.segments.first { $0.text == "second" }
        #expect(secondSeg != nil)
        #expect(secondSeg?.start == 95.0)   // 35 + 60
        #expect(secondSeg?.end   == 100.0)  // 40 + 60
    }

    @Test func mergeSkipsSegmentsInsideOverlapWindow() {
        // Segments with start < 30 s in the second+ chunk are in the overlap region and must be skipped
        let r1 = result(text: "first", segments: [seg(id: 0, start: 5, end: 10, text: "first")])
        let c1 = chunk(start: 0, end: 60, index: 0)

        let overlapSeg = seg(id: 0, start: 10, end: 20, text: "overlap")  // start < 30 → skip
        let validSeg   = seg(id: 1, start: 35, end: 45, text: "valid")    // start >= 30 → keep
        let r2 = result(text: "overlap valid", segments: [overlapSeg, validSeg])
        let c2 = chunk(start: 60, end: 120, index: 1)

        let merged = AudioPreprocessor().mergeChunkedTranscriptions([
            (chunk: c1, result: r1), (chunk: c2, result: r2)
        ])

        let texts = merged.segments.map(\.text)
        #expect(!texts.contains("overlap"))
        #expect(texts.contains("valid"))
    }

    @Test func mergePreservesLanguageAndModelFromFirstChunk() {
        let r1 = result(text: "a", language: "sv", model: "kb_whisper-large")
        let c1 = chunk(start: 0, end: 60, index: 0)

        let r2 = result(text: "b", language: "en", model: "other")
        let c2 = chunk(start: 60, end: 120, index: 1)

        let merged = AudioPreprocessor().mergeChunkedTranscriptions([
            (chunk: c1, result: r1), (chunk: c2, result: r2)
        ])

        #expect(merged.language  == "sv")
        #expect(merged.modelUsed == "kb_whisper-large")
    }

    @Test func mergeSegmentIDsAreSequential() {
        // Merged segment IDs should be 0, 1, 2, … regardless of source IDs
        let r1 = result(text: "a b", segments: [
            seg(id: 99, start: 5,  end: 10, text: "a"),
            seg(id: 77, start: 15, end: 20, text: "b"),
        ])
        let c1 = chunk(start: 0, end: 60, index: 0)

        let merged = AudioPreprocessor().mergeChunkedTranscriptions([(chunk: c1, result: r1)])
        #expect(merged.segments[0].id == 0)
        #expect(merged.segments[1].id == 1)
    }
}

// MARK: - TranscriptionModel Tests

struct TranscriptionModelTests {

    @Test func transcriptionResultCodableRoundTrip() throws {
        let original = TranscriptionResult(
            text: "Hello world",
            segments: [
                TranscriptionSegment(id: 0, start: 0.0, end: 1.5, text: "Hello world",
                                     confidence: 0.95, speaker: nil)
            ],
            language: "en",
            duration: 10.5,
            timestamp: Date(timeIntervalSince1970: 1_000_000),
            modelUsed: "test-model"
        )
        let data    = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TranscriptionResult.self, from: data)

        #expect(decoded.id        == original.id)
        #expect(decoded.text      == original.text)
        #expect(decoded.language  == original.language)
        #expect(decoded.duration  == original.duration)
        #expect(decoded.modelUsed == original.modelUsed)
        #expect(decoded.segments.count == 1)
        #expect(decoded.segments[0].confidence == 0.95)
    }

    @Test func transcriptionSegmentCodablePreservesOptionals() throws {
        // With values set
        let withValues = TranscriptionSegment(id: 1, start: 0.5, end: 1.0,
                                              text: "test", confidence: 0.8, speaker: "Speaker 1")
        let d1  = try JSONEncoder().encode(withValues)
        let dec1 = try JSONDecoder().decode(TranscriptionSegment.self, from: d1)
        #expect(dec1.confidence == 0.8)
        #expect(dec1.speaker    == "Speaker 1")

        // With nils
        let withNils = TranscriptionSegment(id: 2, start: 0, end: 1, text: "test",
                                            confidence: nil, speaker: nil)
        let d2   = try JSONEncoder().encode(withNils)
        let dec2 = try JSONDecoder().decode(TranscriptionSegment.self, from: d2)
        #expect(dec2.confidence == nil)
        #expect(dec2.speaker    == nil)
    }

    @Test func textProcessingPromptCodableRoundTrip() throws {
        let original = TextProcessingPrompt(name: "Summary", prompt: "Summarize the following:")
        let data    = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TextProcessingPrompt.self, from: data)
        #expect(decoded.id     == original.id)
        #expect(decoded.name   == original.name)
        #expect(decoded.prompt == original.prompt)
    }

    @Test func textProcessingPromptEquality() {
        let id   = UUID()
        let date = Date(timeIntervalSince1970: 1_000_000)
        let p1 = TextProcessingPrompt(id: id, name: "Same", prompt: "same", createdAt: date)
        let p2 = TextProcessingPrompt(id: id, name: "Same", prompt: "same", createdAt: date)
        let p3 = TextProcessingPrompt(id: UUID(), name: "Same", prompt: "same", createdAt: date)

        #expect(p1 == p2)  // identical in all fields → equal
        #expect(p1 != p3)  // different UUID → not equal
    }

    @Test func formattedTextJoinsSegmentTextsWithSpaces() {
        let result = TranscriptionResult(
            text: "Hello world today",
            segments: [
                TranscriptionSegment(id: 0, start: 0, end: 1, text: "Hello",  confidence: nil, speaker: nil),
                TranscriptionSegment(id: 1, start: 1, end: 2, text: "world",  confidence: nil, speaker: nil),
                TranscriptionSegment(id: 2, start: 2, end: 3, text: "today",  confidence: nil, speaker: nil),
            ],
            language: "en", duration: 3, timestamp: Date(), modelUsed: "test"
        )
        #expect(result.formattedText == "Hello world today")
    }

    @Test func formattedTextIsEmptyWhenNoSegments() {
        let result = TranscriptionResult(
            text: "", segments: [], language: "en",
            duration: 0, timestamp: Date(), modelUsed: "test"
        )
        #expect(result.formattedText == "")
    }
}

// MARK: - AppState Tests

@MainActor
struct AppStateTests {

    @Test func initialStateIsClean() {
        let state = AppState()
        #expect(state.currentTranscriptionURL == nil)
        #expect(state.showTranscriptionView   == false)
        #expect(state.showRecordingView       == false)
        #expect(state.showSystemAudioView     == false)
        #expect(state.showSammanfattaView     == false)
        #expect(state.sammanfattaText         == "")
    }

    @Test func openFileForTranscriptionSetsURLAndShowsView() {
        let state = AppState()
        let url   = URL(fileURLWithPath: "/tmp/recording.wav")
        state.openFileForTranscription(url)
        #expect(state.currentTranscriptionURL == url)
        #expect(state.showTranscriptionView   == true)
    }

    @Test func openSammanfattaSetsTextAndShowsView() {
        let state = AppState()
        state.openSammanfatta(text: "Meeting summary here")
        #expect(state.sammanfattaText     == "Meeting summary here")
        #expect(state.showSammanfattaView == true)
    }

    @Test func openFileDoesNotAffectOtherViewFlags() {
        let state = AppState()
        state.openFileForTranscription(URL(fileURLWithPath: "/tmp/file.wav"))
        #expect(state.showRecordingView   == false)
        #expect(state.showSystemAudioView == false)
        #expect(state.showSammanfattaView == false)
    }

    @Test func openSammanfattaDoesNotAffectOtherViewFlags() {
        let state = AppState()
        state.openSammanfatta(text: "text")
        #expect(state.showTranscriptionView == false)
        #expect(state.showRecordingView     == false)
        #expect(state.showSystemAudioView   == false)
    }
}
