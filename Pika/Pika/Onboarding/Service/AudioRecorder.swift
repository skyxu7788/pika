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

    func start(onTranscript: @escaping (String) -> Void) async throws {
        let canRecord = await requestRecordPermission()
        guard canRecord else {
            throw AudioRecorderError.permissionDenied
        }

        let canRecognizeSpeech = await requestSpeechPermission()
        guard canRecognizeSpeech else {
            throw AudioRecorderError.speechPermissionDenied
        }

        stopEngine()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setPreferredIOBufferDuration(0.01)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("caf")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, _ in
            guard let transcript = result?.bestTranscription.formattedString else { return }
            onTranscript(transcript)
        }

        audioFile = file
        recordingURL = url
        recognitionRequest = request

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.recognitionRequest?.append(buffer)
            try? self.audioFile?.write(from: buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
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
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func stopEngine() {
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
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
}

private enum AudioRecorderError: Error {
    case permissionDenied
    case speechPermissionDenied
    case notRecording
}
