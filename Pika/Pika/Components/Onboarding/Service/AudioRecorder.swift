//
//  AudioRecorder.swift
//  Pika
//
//  Created by S J on 5/28/26.
//

import AVFoundation
import Foundation
import Speech

final class AudioRecorder {
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    private var audioFile: AVAudioFile?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recordingURL: URL?
    private var didInstallTap = false
    private var debugBufferCount = 0
    private var lastDebugLogTime = Date.distantPast

    func start(
        onTranscript: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void
    ) async throws {
        let canRecord = await requestRecordPermission()
        guard canRecord else {
            throw AudioRecorderError.permissionDenied
        }

        let canRecognizeSpeech = await requestSpeechPermission()
        guard canRecognizeSpeech else {
            throw AudioRecorderError.speechPermissionDenied
        }

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw AudioRecorderError.speechRecognizerUnavailable
        }

        stopEngine()
        debugBufferCount = 0
        lastDebugLogTime = .distantPast

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setPreferredIOBufferDuration(0.01)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        if session.isInputGainSettable {
            try? session.setInputGain(1.0)
        }
        print("audio session input: \(session.currentRoute.inputs.map(\.portName).joined(separator: ", "))")
        print("audio input gain settable: \(session.isInputGainSettable), gain=\(session.inputGain)")

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        print("audio tap format: sampleRate=\(format.sampleRate), channels=\(format.channelCount), commonFormat=\(format.commonFormat.rawValue)")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("caf")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if #available(iOS 16.0, *) {
            request.addsPunctuation = false
        }

        recognitionRequest = request

        recognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
            if let transcript = result?.bestTranscription.formattedString, !transcript.isEmpty {
                print("speech transcript: \(transcript)")
                onTranscript(transcript)
            }

            if let error {
                onError(error)
            }
        }

        audioFile = file
        recordingURL = url

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.logAudioLevelIfNeeded(buffer)
            self.recognitionRequest?.append(buffer)
            do {
                try self.audioFile?.write(from: buffer)
            } catch {
                onError(error)
            }
        }
        didInstallTap = true

        audioEngine.prepare()
        try audioEngine.start()
        print("audio engine started: \(audioEngine.isRunning)")
    }

    func stop() throws -> Data {
        guard let recordingURL else {
            throw AudioRecorderError.notRecording
        }

        stopEngine()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        let data = try Data(contentsOf: recordingURL)
        try? FileManager.default.removeItem(at: recordingURL)
        self.recordingURL = nil
        return data
    }

    private func requestRecordPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { isGranted in
                continuation.resume(returning: isGranted)
            }
        }
    }

    private func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
              print("speech auth status: \(status)")
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func stopEngine() {
        if didInstallTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            didInstallTap = false
        }

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioFile = nil
    }

    private func logAudioLevelIfNeeded(_ buffer: AVAudioPCMBuffer) {
        debugBufferCount += 1

        let now = Date()
        guard now.timeIntervalSince(lastDebugLogTime) >= 0.5 else { return }
        lastDebugLogTime = now

        let metrics = audioMetrics(in: buffer)
        let isSilent = metrics.peak < 0.0005
        print("audio tap buffer #\(debugBufferCount), frames=\(buffer.frameLength), peak=\(metrics.peak), rms=\(metrics.rms), dBFS=\(metrics.dbfs), silent=\(isSilent)")
    }

    private func audioMetrics(in buffer: AVAudioPCMBuffer) -> (peak: Float, rms: Float, dbfs: Float) {
        if let channels = buffer.floatChannelData {
            var peak: Float = 0
            var sumSquares: Float = 0
            var sampleCount: Float = 0
            let channelCount = Int(buffer.format.channelCount)
            let frameLength = Int(buffer.frameLength)

            for channel in 0..<channelCount {
                let samples = channels[channel]
                for frame in 0..<frameLength {
                    let sample = samples[frame]
                    peak = max(peak, abs(sample))
                    sumSquares += sample * sample
                    sampleCount += 1
                }
            }

            let rms = sampleCount > 0 ? sqrt(sumSquares / sampleCount) : 0
            return (peak, rms, dbfs(for: rms))
        }

        if let channels = buffer.int16ChannelData {
            var peak: Int16 = 0
            var sumSquares: Float = 0
            var sampleCount: Float = 0
            let channelCount = Int(buffer.format.channelCount)
            let frameLength = Int(buffer.frameLength)

            for channel in 0..<channelCount {
                let samples = channels[channel]
                for frame in 0..<frameLength {
                    let sample = Float(samples[frame]) / Float(Int16.max)
                    peak = max(peak, abs(samples[frame]))
                    sumSquares += sample * sample
                    sampleCount += 1
                }
            }

            let normalizedPeak = Float(peak) / Float(Int16.max)
            let rms = sampleCount > 0 ? sqrt(sumSquares / sampleCount) : 0
            return (normalizedPeak, rms, dbfs(for: rms))
        }

        return (0, 0, -.infinity)
    }

    private func dbfs(for rms: Float) -> Float {
        guard rms > 0 else { return -.infinity }
        return 20 * log10(rms)
    }
}

private enum AudioRecorderError: Error {
    case permissionDenied
    case speechPermissionDenied
    case speechRecognizerUnavailable
    case notRecording
}
